locals {
  name = "auto-discovery"
}

data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false
}

# calling ACM certificate
data "aws_acm_certificate" "cert" {
  domain      = var.domain_name
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

module "vpc" {
  source = "./module/vpc"
  name   = local.name
  az1    = "eu-west-1a"
  az2    = "eu-west-1b"
}

module "bastion" {
  source       = "./module/bastion"
  name         = local.name
  vpc          = module.vpc.vpc_id
  subnets      = [module.vpc.public_subnet1_id, module.vpc.public_subnet2_id]
  keypair      = module.vpc.public_key
  privatekey   = module.vpc.private_key
  nr_acc_id    = var.nr_acc_id
  nr_key_param = var.nr_key_param
  region       = var.region
}

module "ansible" {
  source               = "./module/ansible"
  name                 = local.name
  keypair              = module.vpc.public_key
  subnet_id            = module.vpc.private_subnet1_id
  vpc                  = module.vpc.vpc_id
  bastion_key          = module.bastion.bastion_sg
  private-key          = module.vpc.private_key
  nexus-ip             = module.nexus.nexus_ip
  nr_key_param         = var.nr_key_param
  region               = var.region
  nr_acc_id            = var.nr_acc_id
  nexus_password_param = var.nexus_password_param
}

module "database" {
  source                 = "./module/database"
  name                   = local.name
  private_subnet1_id     = module.vpc.private_subnet1_id
  private_subnet2_id     = module.vpc.private_subnet2_id
  bastion-security-group = module.bastion.bastion_sg
  vpc-id                 = module.vpc.vpc_id
  stage-security-group   = module.stage-env.stage_sg
  prod-security-group    = module.prod-env.prod_sg
}

module "sonarqube" {
  source                   = "./module/sonarqube"
  name                     = local.name
  vpc                      = module.vpc.vpc_id
  vpc_cidr_block           = "10.0.0.0/16"
  keypair                  = module.vpc.public_key
  subnet_id                = module.vpc.public_subnet1_id
  subnets                  = module.vpc.public_subnet1_id
  certificate              = data.aws_acm_certificate.cert.arn
  hosted_zone_id           = data.aws_route53_zone.zone.id
  domain_name              = var.domain_name
  sonarqube_password_param = var.sonarqube_password_param
  region                   = var.region
}

module "prod-env" {
  source               = "./module/prod-env"
  name                 = local.name
  vpc-id               = module.vpc.vpc_id
  bastion              = module.bastion.bastion_sg
  key-name             = module.vpc.public_key
  pri-subnet1          = module.vpc.private_subnet1_id
  pri-subnet2          = module.vpc.private_subnet2_id
  pub-subnet1          = module.vpc.public_subnet1_id
  pub-subnet2          = module.vpc.public_subnet2_id
  acm-cert-arn         = data.aws_acm_certificate.cert.arn
  domain               = var.domain_name
  hosted_zone_id       = data.aws_route53_zone.zone.zone_id
  nexus-ip             = module.nexus.nexus_ip
  nr_key_param         = var.nr_key_param
  region               = var.region
  nr_acc_id            = var.nr_acc_id
  ansible              = module.ansible.ansible_sg
  nexus_password_param = var.nexus_password_param
}

module "stage-env" {
  source               = "./module/stage-env"
  name                 = local.name
  vpc-id               = module.vpc.vpc_id
  bastion              = module.bastion.bastion_sg
  key-name             = module.vpc.public_key
  pri-subnet1          = module.vpc.private_subnet1_id
  pri-subnet2          = module.vpc.private_subnet2_id
  pub-subnet1          = module.vpc.public_subnet1_id
  pub-subnet2          = module.vpc.public_subnet2_id
  acm-cert-arn         = data.aws_acm_certificate.cert.arn
  domain               = var.domain_name
  hosted_zone_id       = data.aws_route53_zone.zone.zone_id
  nexus-ip             = module.nexus.nexus_ip
  nr_key_param         = var.nr_key_param
  region               = var.region
  nr_acc_id            = var.nr_acc_id
  ansible              = module.ansible.ansible_sg
  nexus_password_param = var.nexus_password_param
}

module "nexus" {
  source               = "./module/nexus"
  name                 = local.name
  vpc                  = module.vpc.vpc_id
  keypair              = module.vpc.public_key
  subnet_id            = module.vpc.public_subnet1_id
  subnets              = module.vpc.public_subnet1_id
  certificate          = data.aws_acm_certificate.cert.arn
  hosted_zone_id       = data.aws_route53_zone.zone.id
  domain_name          = var.domain_name
  nexus_password_param = var.nexus_password_param
  region               = var.region
}
