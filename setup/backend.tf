terraform {
  backend "s3" {
    bucket         = "mytodoeksbucket"
    key            = "jenkins/terraform.tfstate"
    dynamodb_table = "eks-backend"
    region         = "eu-west-2"
    encrypt        = true
    # profile        = "team1"
  }
}