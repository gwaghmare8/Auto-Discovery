# create aws provider
provider "aws" {
  region  = var.region
  profile = "default"
}

# terraform {
#   backend "s3" {
#     bucket         = "pet-adoption-state-bucket-one-team-1"
#     key            = "vault-jenkins/terraform.tfstate"
#     region         = "eu-west-3"
#     encrypt        = true
#     dynamodb_table = "pet-adoption-state-bucket-one-dynamodb-lock-team-1"
#     profile        = "default"
#   }
# }

terraform {
  backend "s3" {
    bucket       = "auto-discovery-terraform-state"
    use_lockfile = false
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    dynamodb_table = "auto-discovery-terraform-state-dynamodb-lock"
    profile      = "default"
  }
}