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
  az1   = "eu-west-1a"
  az2   = "eu-west-1b"
}

module "Bastion" {
  source     = "./module/Bastion"
  name       = local.name
  vpc        = module.vpc.vpc_id
  subnets    = [module.vpc.public_subnet1_id, module.vpc.public_subnet2_id]
  keypair    = module.vpc.public_key
  privatekey = module.vpc.private_key
    nr_acc_id  = var.nr_acc_id
    nr_key     = var.nr_key
}

module "Ansible" {
  source      = "./module/Ansible"
  name        = local.name
  keypair     = module.vpc.public_key
  subnet_id   = module.vpc.private_subnet1_id
  vpc         = module.vpc.vpc_id
  bastion_key = module.Bastion.bastion_sg
  private-key = module.vpc.private_key
  nexus-ip    = module.nexus.nexus_ip
    nr_key      = var.nr_key
    nr_acc_id   = var.nr_acc_id
}