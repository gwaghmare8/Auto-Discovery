locals {
  name = "auto-discovery"
}

data "aws_route53_zone" "zone" {
  name         = "var.domain_name"
  private_zone = false
}

# calling ACM certificate
data "aws_acm_certificate" "cert" {
  domain   = "var.domain_name"
  types = ["AMAZON_ISSUED"]
  most_recent = true
}

module "vpc" {
  source = "./module/vpc"
  name  = local.name
  az1   = "eu-west-3a"
  az2   = "eu-west-3b"
}