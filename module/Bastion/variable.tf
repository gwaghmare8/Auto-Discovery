variable "name" {}
variable "vpc" {}
variable "subnets" {
  type        = list(string)
  description = "List of subnet IDs"
}
variable "privatekey" {}
variable "nr_key_param" {}
variable "nr_acc_id" {}
variable "keypair" {}
variable "region" {}

