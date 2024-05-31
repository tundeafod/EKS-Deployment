pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION = 'eu-west-2'
    }
    stages {
        stage('Checkout SCM') {
            steps {
                script {
                    checkout([$class: 'GitSCM',
                        branches: [[name: '*/main']],
                        extensions: [],
                        userRemoteConfigs: [[url: 'https://github.com/tundeafod/EKS-Deployment.git']]
                    ])
                }
            }
        }
        stage('Initializing Terraform') {
            steps {
                sh 'terraform init'
            }
        }
        stage('Formatting Terraform code') {
            steps {
                sh 'terraform fmt'
            }
        }
        stage('Validating Terraform') {
            steps {
                sh 'terraform validate'
            }
        }
        stage('Previewing the Infrastructure') {
            steps {
                sh 'terraform plan'
            }
        }
        stages('Creating/Destroying an EKS cluster') {
            steps {
                sh 'terraform ${action} --auto-approve'
            }
        }
    }
}
