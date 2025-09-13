pipeline {
    agent any

    environment {
        AWS_REGION = "us-east-1"
        ECR_REPO = "338034595180.dkr.ecr.us-east-1.amazonaws.com/my-nodejs-app"
        IMAGE_TAG = "latest"
    }

    stages {
        stage('Checkout') {
            steps {
                echo "🔹 Pulling latest code from GitHub dev branch"
                git url: 'https://github.com/pathasaradi/devops-task.git', 
                    branch: 'dev', 
                    credentialsId: 'github-jenkins-token'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "🔹 Building Docker image for Node.js app"
                sh """
                aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
                docker build -t $ECR_REPO:$IMAGE_TAG .
                """
            }
        }

        stage('Push to ECR') {
            steps {
                echo "🔹 Pushing Docker image to AWS ECR"
                sh "docker push $ECR_REPO:$IMAGE_TAG"
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
