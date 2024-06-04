locals {
  name = "eksJenkins"
}

#Vpc
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks_cluster_vpc"
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.azs.names
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets


  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/elb"               = 1

  }
  private_subnet_tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/private_elb"       = 1

  }
}

#EKS

module "eks" {
  source                         = "terraform-aws-modules/eks/aws"
  cluster_name                   = "my-eks-cluster"
  cluster_version                = "1.29"
  cluster_endpoint_public_access = true
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = var.instance_types
    }
    two = {
      name = "node-group-2"

      instance_types = var.instance_types

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }
}

#Bastion host
resource "aws_instance" "bastion_server" {
  ami                         = "ami-035cecbff25e0d91e" #ec2-user
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.bastion-sg.id, module.eks.node_security_group_id, module.eks.cluster_security_group_id]
  subnet_id                   = "module.vpc.public_subnets"
  associate_public_ip_address = true
  # user_data                   = <<-EOF
  # #!/bin/bash
  # echo "${var.private_keypair}" > /home/ec2-user/.ssh/id_rsa
  # chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
  # chmod 600 /home/ec2-user/.ssh/id_rsa
  # sudo hostnamectl set-hostname Bastion
  # EOF  
  tags = {
    Name = "${local.name}-bastion"
  }
}

# Creating Bastion security group
resource "aws_security_group" "bastion-sg" {
  name        = "bastion security group"
  description = "bastion security Group"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-bastion-sg"
  }
}

# Creating RSA key of size 4096 bits
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "keypair" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "eksbastion-keypair.pem"
  file_permission = "600"
}
# Creating keypair
resource "aws_key_pair" "keypair" {
  key_name   = "eksbastion-keypair"
  public_key = tls_private_key.keypair.public_key_openssh
}
