pipeline {
    agent any

    // Environment variables for AWS and Docker
    environment {
        AWS_REGION = "us-east-1"
        ECR_REPO = "338034595180.dkr.ecr.us-east-1.amazonaws.com/my-nodejs-app"
        IMAGE_TAG = "latest"
    }

    stages {
        // Stage 1: Checkout code from GitHub
        stage('Checkout') {
            steps {
                echo "🔹 Pulling latest code from GitHub dev branch"
                git(
                    url: 'https://github.com/pathasaradi/devops-task.git',
                    credentialsId: 'github-jenkins-token',
                    branch: 'dev'
                )
            }
        }

        // Stage 2: Build Docker Image
        stage('Build Docker Image') {
            steps {
                echo "🔹 Building Docker image for Node.js app"
                script {
                    sh """
                    # Login to AWS ECR
                    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 338034595180.dkr.ecr.us-east-1.amazonaws.com
                    # Build Docker image
                    docker build -t $ECR_REPO:$IMAGE_TAG .
                    """
                }
            }
        }

        // Stage 3: Push Docker Image to ECR
        stage('Push to ECR') {
            steps {
                echo "🔹 Pushing Docker image to AWS ECR"
                script {
                    sh "docker push $ECR_REPO:$IMAGE_TAG"
                }
            }
        }
    }
    
    post {
        success {
            echo "✅ Pipeline completed successfully! Docker image is in ECR."
        }
        failure {
            echo "❌ Pipeline failed. Check logs for details."
        }
    }
}
