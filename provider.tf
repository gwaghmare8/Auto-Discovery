provider "aws" {
  region  = "eu-west-1"
  # profile = "default"
}

terraform {
  backend "s3" {
    bucket       = "auto-discovery-terraform-state"
    use_lockfile = false
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    dynamodb_table = "auto-discovery-terraform-state-dynamodb-lock"
    # profile      = "default"
  }
}

provider "vault" {
  address = "https://vault.gaurav-devops.site"
}
