terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# --------------------
# VARIABLES
# --------------------
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "devops-task"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "172.31.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnets CIDRs (at least 2 recommended)"
  type        = list(string)
  default     = ["172.31.16.0/20", "172.31.48.0/20"]
}

variable "desired_count" {
  description = "ECS service desired count"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port exposed by container"
  type        = number
  default     = 3000
}

variable "image_tag" {
  description = "Image tag to use for the task (push your image to ECR after creation)"
  type        = string
  default     = "latest"
}

# --------------------
# NETWORKING: VPC + Public Subnets
# --------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.project_name}-pub-${count.index + 1}"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --------------------
# SECURITY GROUP
# --------------------
resource "aws_security_group" "svc_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow inbound HTTP to container and all outbound"
  vpc_id      = aws_vpc.this.id

  ingress {
    description      = "HTTP from anywhere"
    from_port        = var.container_port
    to_port          = var.container_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # optional SSH from your admin IP - commented out by default
  # ingress {
  #   description = "SSH from admin"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["<YOUR_IP>/32"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }
}

# --------------------
# ECR Repository
# --------------------
resource "aws_ecr_repository" "repo" {
  name                 = "${var.project_name}"
  image_scanning_configuration {
    scan_on_push = false
  }
  tags = { Name = "${var.project_name}-ecr" }
}

# --------------------
# CloudWatch Log Group
# --------------------
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14
  tags              = { Name = "${var.project_name}-logs" }
}

# --------------------
# IAM Role for ECS Task Execution
# --------------------
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })

  tags = { Name = "${var.project_name}-ecs-exec-role" }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# (Optionally attach CloudWatch full access if you want more logs actions)
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# --------------------
# ECS Cluster
# --------------------
resource "aws_ecs_cluster" "Partha-cluster" {
  name = "${var.project_name}-cluster"
  tags = { Name = "${var.project_name}-cluster" }
}

# --------------------
# ECS Task Definition (Fargate)
# --------------------
resource "aws_ecs_task_definition" "partha-task" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "3072"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.repo.repository_url}:${var.image_tag}"
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# --------------------
# ECS Service (Fargate)
# --------------------
resource "aws_ecs_service" "partha-service" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.svc_sg.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [task_definition] # optional: allow manual task def updates
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_execution_policy]
}

# --------------------
# OUTPUTS
# --------------------
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "security_group_id" {
  value = aws_security_group.svc_sg.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.repo.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.service.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.task.arn
}
