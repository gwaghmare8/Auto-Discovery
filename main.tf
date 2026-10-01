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

module "database" {
  source     = "./module/database"
  name       = local.name
  private_subnet1_id = module.vpc.private_subnet1_id
  private_subnet2_id = module.vpc.private_subnet2_id
  bastion-security-group = module.Bastion.bastion_sg
  vpc-id     = module.vpc.vpc_id
  stage-security-group   = module.stage-env.stage_sg
  prod-security-group    = module.prod-env.prod_sg
}

module "sonaqube" {
  source         = "./module/sonaqube"
  name           = local.name
  vpc            = module.vpc.vpc_id
  vpc_cidr_block = "10.0.0.0/16"
  keypair        = module.vpc.public_key
  subnet_id      = module.vpc.public_subnet1_id
  subnets        = module.vpc.public_subnet1_id
  certificate    = data.aws_acm_certificate.cert.arn
  hosted_zone_id = data.aws_route53_zone.zone.id
  domain_name    = var.domain_name
}

module "prod-env" {
  source       = "./module/prod-env"
  name         = local.name
  vpc-id       = module.vpc.vpc_id
  bastion    = module.Bastion.bastion_sg
  key-name     = module.vpc.public_key
  pri-subnet1  = module.vpc.private_subnet1_id
  pri-subnet2  = module.vpc.private_subnet2_id
  pub-subnet1  = module.vpc.public_subnet1_id
  pub-subnet2  = module.vpc.public_subnet2_id
  acm-cert-arn = data.aws_acm_certificate.cert.arn
  domain       = var.domain_name
  nexus-ip     = module.nexus.nexus_ip
    nr_key       = var.nr_key
    nr_acc_id    = var.nr_acc_id
  ansible      = module.Ansible.ansible_sg
}
module "stage-env" {
  source       = "./module/stage-env"
  name         = local.name
  vpc-id       = module.vpc.vpc_id
  bastion     = module.Bastion.bastion_sg
  key-name     = module.vpc.public_key
  pri-subnet1  = module.vpc.private_subnet1_id
  pri-subnet2  = module.vpc.private_subnet2_id
  pub-subnet1  = module.vpc.public_subnet1_id
  pub-subnet2  = module.vpc.public_subnet2_id
  acm-cert-arn = data.aws_acm_certificate.cert.arn
  domain       = var.domain_name
  nexus-ip     = module.nexus.nexus_ip
    nr_key       = var.nr_key
    nr_acc_id    = var.nr_acc_id
  ansible      = module.Ansible.ansible_sg
}

module "nexus" {
  source         = "./module/nexus"
  name           = local.name
  vpc            = module.vpc.vpc_id
  keypair        = module.vpc.public_key
  subnet_id      = module.vpc.public_subnet1_id
  subnets        = module.vpc.public_subnet1_id
  certificate    = data.aws_acm_certificate.cert.arn
  hosted_zone_id = data.aws_route53_zone.zone.id
  domain_name    = var.domain_name
}
