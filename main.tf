# RSA key of size 4096 bits
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "keypair" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "cluster-access.pem"
  file_permission = "600"
}

resource "aws_key_pair" "public-key" {
  key_name   = "cluster-access"
  public_key = tls_private_key.keypair.public_key_openssh
}

# Creating remote server
resource "aws_instance" "cluster-access" {
  ami                         = "ami-053a617c6207ecc7b"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.cluster-access-sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.cluster-access-profile.id
  key_name                    = aws_key_pair.public-key.id
  user_data                   = file("cluster-install.sh")

  tags = {
    Name = "cluster-access"
  }
}

# Create null resource to copy
resource "null_resource" "copy-eks-file" {
  connection {
    type        = "ssh"
    host        = aws_instance.cluster-access.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.keypair.private_key_pem
  }
  provisioner "file" {
    source      = "./eks-code"
    destination = "/home/ubuntu/eks-code"
  }
}

# Create IAM User
resource "aws_iam_user" "eks_user" {
  name = "eks_user"
}

# Create IAM Access Key
resource "aws_iam_access_key" "eks_user_key" {
  user = aws_iam_user.eks_user.name
}

# Create IAM Group
resource "aws_iam_group" "eks_group" {
  name = "eks_group"
}

resource "aws_iam_user_group_membership" "eks_group_membership" {
  user   = aws_iam_user.eks_user.name
  groups = [aws_iam_group.eks_group.name]
}

# Create IAM Policy
resource "aws_iam_group_policy_attachment" "eks_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  group      = aws_iam_group.eks_group.name
}

#  Create IAM Policy
resource "aws_iam_role_policy_attachment" "cluster-access-policy-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.cluster-access-role.name
}

# Create IAM Role
resource "aws_iam_role" "cluster-access-role" {
  name               = "cluster-access-role"
  assume_role_policy = file("${path.root}/ec2-assume.json")
}

# Create IAM Instance Profile
resource "aws_iam_instance_profile" "cluster-access-profile" {
  name = "cluster-access-profile"
  role = aws_iam_role.cluster-access-role.name
}

resource "aws_security_group" "cluster-access-sg" {
  tags = {
    Name = "cluster-access-sg"
  }
}

resource "aws_security_group_rule" "allow-ingress-remote-host-sg" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster-access-sg.id
}

resource "aws_security_group_rule" "egress-all-remote-host-sg" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster-access-sg.id
}