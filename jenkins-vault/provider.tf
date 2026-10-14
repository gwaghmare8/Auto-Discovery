# create aws provider
provider "aws" {
  region  = var.region
  profile = "default"
}

terraform {
  backend "s3" {
    bucket         = "auto-discovery-terraform-state"
    key            = "vault-jenkins/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "auto-discovery-terraform-state-dynamodb-lock"
    profile        = "default"
  }
}