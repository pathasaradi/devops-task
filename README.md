🚀 ECS Fargate Deployment – DevOps Partha Task

This repository documents how we built, pushed, and deployed a Dockerized application to Amazon ECS (Fargate) using Jenkins CI/CD.
It includes all steps, configurations, and commands so anyone can reproduce this setup.

📌 Architecture Overview

<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/21a9c697-47f6-4045-a2f7-094d4d8fe813" />


Components Used:

Jenkins → Automates build, push, and ECS service update.

Amazon ECR → Stores Docker images.

Amazon ECS (Fargate) → Runs the containerized workload serverlessly.

VPC + Subnets + Security Groups → Provides networking and security.

CloudWatch Logs → Stores logs for debugging and monitoring.

🛠️ Step-by-Step Setup
1️⃣ Create an ECR Repository

Go to Amazon ECR → Create Repository.

Name the repo: devops-partha-task (or any name you prefer).

Copy the ECR URI:

338034595180.dkr.ecr.us-east-1.amazonaws.com/devops-partha-task

2️⃣ Build and Push Docker Image to ECR
# Authenticate Docker with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin AWS ACCOUNT Id.dkr.ecr.us-east-1.amazonaws.com

# Build Docker image
docker build -t devops-partha-task:latest .

# Tag image for ECR
docker tag devops-partha-task:latest AWS ACCOUNT ID.dkr.ecr.us-east-1.amazonaws.com/devops-partha-task:latest

# Push image to ECR
docker push AWS ACCOUNT ID.dkr.ecr.us-east-1.amazonaws.com/devops-partha-task:latest


✅ Now your image is stored in ECR.

3️⃣ Create ECS Cluster (Fargate)

Go to Amazon ECS → Clusters → Create Cluster.

Choose Networking Only (Fargate).

Name the cluster: devops-partha-cluster.

Create the cluster.

4️⃣ Create ECS Task Definition

Go to Task Definitions → Create new task definition.

Launch type → Fargate.

Task definition name: devops-partha-task.

Container details:

Container name: devops-container

Image URI: AWS ACCOUNT ID.dkr.ecr.us-east-1.amazonaws.com/devops-partha-task:latest

Port mapping: 3000:3000

Logging:

Enable CloudWatch Logs

Log group name: /ecs/devops-partha-task

Create the task definition.

5️⃣ Create ECS Service

Go to ECS → Clusters → devops-partha-cluster → Create Service.

Select:

Launch type: Fargate

Task definition: devops-partha-task:1

Service name: devops-partha-service

Desired tasks: 1

Configure networking:

Subnets: Select 2 private/public subnets

Security group: Allow inbound on port 3000

Assign Public IP: ENABLED

Create service.

6️⃣ Verify Running Task

Go to ECS → Clusters → devops-partha-cluster → Tasks.

Confirm 1/1 task is running.

Open the ENI (Elastic Network Interface) linked to the task.

Copy the Public IPv4 address.

Access in browser:

http://<PUBLIC_IP>:3000


✅ Your container should be running and accessible.

7️⃣ Jenkins CI/CD Pipeline Setup

Attach an IAM Role to the Jenkins instance with:

AmazonEC2ContainerRegistryFullAccess

AmazonECS_FullAccess

CloudWatchLogsFullAccess

Create a Jenkinsfile in your repo:

pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        ECR_REPO = "AWS ACCOUNT ID.dkr.ecr.us-east-1.amazonaws.com/devops-partha-task"
        IMAGE_TAG = "latest"
        CLUSTER = "devops-partha-cluster"
        SERVICE = "devops-partha-service"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'dev', url: 'https://github.com/pathasaradi/devops-task.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                echo "Building Docker image..."
                docker build -t $ECR_REPO:$IMAGE_TAG .
                '''
            }
        }

        stage('Login to ECR') {
            steps {
                sh '''
                aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                docker push $ECR_REPO:$IMAGE_TAG
                '''
            }
        }

        stage('Deploy to ECS') {
            steps {
                sh '''
                echo "Forcing ECS service to deploy latest image..."
                aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment --region $AWS_REGION
                '''
            }
        }
    }
}

8️⃣ Testing the CI/CD

Commit and push code to the repo.

Run the Jenkins pipeline.

Verify:

New Docker image is built and pushed to ECR.

ECS service is updated and redeploys a new task.

Application is accessible via public IP.

📜 Notes & Best Practices

Keep sensitive data (like credentials) in Jenkins credentials store, not in the pipeline file.

Use latest tag carefully; prefer versioned tags for rollback capability.

Monitor ECS task logs in CloudWatch Logs.

For production, use an Application Load Balancer (ALB) instead of direct public IP.

✅ Maintained by: Partha – AWS DevOps Engineer
