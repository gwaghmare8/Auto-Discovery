variable "keypair" {}
variable "name" {}
variable "subnet_id" {}
variable "vpc" {}
variable "bastion_key" {}
variable "private-key" {}
variable "nexus-ip" {}
variable "nr_key_param" {}
variable "nr_acc_id" {}

variable "artifacts_bucket" {
  description = "S3 bucket holding the Ansible scripts (shared with the Terraform state bucket)"
  default     = "auto-discovery-terraform-state"
}
variable "region" {}
variable "nexus_password_param" {}
