variable "name" {}
variable "vpc" {}
variable "subnets" {
    type = list(string)
    description = "List of subnet IDs"
}
  
