variable "name" {}
variable "vpc" {}
variable "subnets" {
    type = list(string)
    description = "List of subnet IDs"
}
variable "privatekey" {}
variable "nr_key" {}
variable "nr_acc_id" {}
variable "keypair" {}
variable "region" {
  default = "eu-west-3"
}

