#!/bin/bash

sudo apt update -y
 
# Install AWS CLI 
sudo apt install unzip 
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure aws cli
sudo su -c "aws configure set aws_access_key_id ${aws_iam_access_key.eks_user_key.id}" ubuntu
sudo su -c "aws configure set aws_secret_access_key ${aws_iam_access_key.eks_user_key.secret}" ubuntu
sudo su -c "aws configure set default.region eu-west-2" ubuntu

# Set Access_keys as ENV Variables
export AWS_ACCESS_KEY_ID=${aws_iam_access_key.eks_user_key.id}
export AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.eks_user_key.secret}

# Installing terraform
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt-get install terraform -y

# Installing Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl 

# Execute terraform script to create EKS Cluster
cd /home/ubuntu/eks-code
terraform init && time terraform apply -auto-approve

# # Update the kubeconfig file allowing users to interact with the EKS Cluster
cd /home/ubuntu/eks-code
sudo su -c "aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)" ubuntu

hostnamectl set-hostname cluster-access