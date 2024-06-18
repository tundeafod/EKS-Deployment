provider "aws" {
  region  = "eu-west-2"
  profile = "team1"
}

terraform {
  backend "s3" {
    bucket         = "mytodoeksbucket"
    key            = "provision/terraform.tfstate"
    dynamodb_table = "eks-backend"
    region         = "eu-west-2"
    encrypt        = true
    profile        = "team1"
  }
}
