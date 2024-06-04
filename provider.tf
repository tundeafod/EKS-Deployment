provider "aws" {
  region  = "eu-west-2"
  profile = "lead"
}

terraform {
  backend "s3" {
    bucket         = "mytodoeksbucket"
    key            = "remote/tfstate"
    dynamodb_table = "eks-backend"
    region         = "eu-west-2"
    encrypt        = true
    profile        = "team1"
  }
}