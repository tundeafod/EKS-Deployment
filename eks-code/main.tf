# locals {
#   name = "eksJenkins"
# }

#Vpc
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "eks_k8cluster_vpc"
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.azs.names
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets


  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = {
    "kubernetes.io/cluster/my-eks-k8cluster" = "shared"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/my-eks-k8cluster" = "shared"
    "kubernetes.io/role/elb"                 = 1

  }
  private_subnet_tags = {
    "kubernetes.io/cluster/my-eks-k8cluster" = "shared"
    "kubernetes.io/role/private_elb"         = 1

  }
}

#EKS

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  cluster_name                             = "my-eks-k8cluster"
  cluster_version                          = "1.29"
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  cluster_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }
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
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
module "irsa-ebs-csi" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.39.0"
  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}
