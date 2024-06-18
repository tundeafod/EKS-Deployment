locals {
  name = "eksJenkins"
}
# create VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${local.name}-vpc"
  }
}
# create pub subnet 1
resource "aws_subnet" "pubsub01" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"
  tags = {
    Name = "${local.name}-pubsub01"
  }
}
# create pub subnet 2
resource "aws_subnet" "pubsub02" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-2b"
  tags = {
    Name = "${local.name}-pubsub02"
  }
}

# create prv subnet 1
resource "aws_subnet" "prvtsub01" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-2a"
  tags = {
    Name = "${local.name}-prvtsub01"
  }
}
# create prv subnet 2
resource "aws_subnet" "prvtsub02" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-2b"
  tags = {
    Name = "${local.name}-prvtsub02"
  }
}

# create an IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.name}-igw"
  }
}
# Allocate Elastic IP Address
resource "aws_eip" "eip" {
  domain = "vpc"
  tags = {
    Name = "${local.name}-EIP"
  }
}
# Create Nat Gateway  in Public Subnet 1
resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.pubsub01.id

  tags = {
    Name = "${local.name}-nat-gateway"
  }
}
# create a public route table
resource "aws_route_table" "public-RT" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${local.name}-public-RT"
  }
}
# assiociation of route table to public subnet 1
resource "aws_route_table_association" "Public-RT-ass" {
  subnet_id      = aws_subnet.pubsub01.id
  route_table_id = aws_route_table.public-RT.id
}
# assiociation of route table to public subnet 2
resource "aws_route_table_association" "Public-RT-ass-2" {
  subnet_id      = aws_subnet.pubsub02.id
  route_table_id = aws_route_table.public-RT.id
}

# Create Private Route Table  and Add Route Through Nat Gateway 
resource "aws_route_table" "private-RT" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gateway.id
  }
  tags = {
    Name = "${local.name}-private-RT"
  }
}
# Associate Private Subnet 1 with "Private Route Table "
resource "aws_route_table_association" "private-subnet-1-route-table-association" {
  subnet_id      = aws_subnet.prvtsub01.id
  route_table_id = aws_route_table.private-RT.id
}
# Associate Private Subnet 2 with "Private Route Table "
resource "aws_route_table_association" "private-subnet-2-route-table-association" {
  subnet_id      = aws_subnet.prvtsub02.id
  route_table_id = aws_route_table.private-RT.id
}

# Creating RSA key of size 4096 bits
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "keypair" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "jenkins-keypair.pem"
  file_permission = "600"
}
# Creating keypair
resource "aws_key_pair" "keypair" {
  key_name   = "jenkins-keypair"
  public_key = tls_private_key.keypair.public_key_openssh
}
#Create Jenkins Server
resource "aws_instance" "jenkins_server" {
  ami                         = "ami-053a617c6207ecc7b" #ubuntu
  instance_type               = "t2.xlarge"
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.id
  subnet_id                   = aws_subnet.pubsub01.id
  key_name                    = aws_key_pair.keypair.id
  user_data                   = file("jenkins-install.sh")
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  tags = {
    Name = "${local.name}-jenkins"
  }
}

# resource "aws_instance" "bastion_server" {
#   ami                         = "ami-035cecbff25e0d91e" #ec2-user
#   instance_type               = "t2.medium"
#   key_name                    = aws_key_pair.keypair.id
#   vpc_security_group_ids      = [aws_security_group.bastion-sg.id]
#   subnet_id                   = aws_subnet.pubsub01.id
#   associate_public_ip_address = true
#   user_data                   = <<-EOF
#   #!/bin/bash
#   echo "${var.private_keypair}" > /home/ec2-user/.ssh/id_rsa
#   chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
#   chmod 600 /home/ec2-user/.ssh/id_rsa
#   sudo hostnamectl set-hostname Bastion
#   EOF  
#   tags = {
#     Name = "${local.name}-bastion"
#   }
# }

# Creating Jenkins security group
resource "aws_security_group" "jenkins-sg" {
  name        = "jenkins"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description = "Allow ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow proxy access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-jenkins-sg"
  }
}
# # Creating Bastion security group
# resource "aws_security_group" "bastion-sg" {
#   name        = "bastion security group"
#   description = "bastion security Group"
#   vpc_id      = aws_vpc.vpc.id
#   ingress {
#     description = "ssh access"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = -1
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = {
#     Name = "${local.name}-bastion-sg"
#    }
# }

#  Create IAM Policy
resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.ec2_role.name
}
# Create IAM Role
resource "aws_iam_role" "ec2_role" {
  name               = "ec2_role2"
  assume_role_policy = file("${path.root}/ec2-assume.json")
}
# Create IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile2"
  role = aws_iam_role.ec2_role.name
}

resource "aws_elb" "jenkins_lb" {
  name            = "jenkins-lb"
  subnets         = [aws_subnet.pubsub02.id, aws_subnet.pubsub01.id]
  security_groups = [aws_security_group.jenkins-sg.id]
  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.acm_certificate.id
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:8080"
    interval            = 30
  }

  instances                   = [aws_instance.jenkins_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${local.name}-jenkins-elb"
  }
}

# Route 53 hosted zone
data "aws_route53_zone" "route53_zone" {
  name         = var.domain-name
  private_zone = false
}

# Create A Route 53 record
resource "aws_route53_record" "jenkins_record" {
  zone_id = data.aws_route53_zone.route53_zone.zone_id
  name    = var.jenkins_domain_name
  type    = "A"
  alias {
    name                   = aws_elb.jenkins_lb.dns_name
    zone_id                = aws_elb.jenkins_lb.zone_id
    evaluate_target_health = true
  }
}

# request public certificates from the amazon certificate manager.
resource "aws_acm_certificate" "acm_certificate" {
  domain_name       = var.domain-name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# create a record set in route 53 for domain validatation
resource "aws_route53_record" "route53_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.route53_zone.zone_id
}

# validate acm certificates
resource "aws_acm_certificate_validation" "acm_certificate_validation" {
  certificate_arn         = aws_acm_certificate.acm_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.route53_record : record.fqdn]
}