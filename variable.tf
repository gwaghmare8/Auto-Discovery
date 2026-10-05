variable "domain_name" {
  default = "gaurav-devops.site"
}

variable "nr_key_param" {
  description = "SSM Parameter Store name that holds the New Relic user API key (created outside Terraform)"
  default     = "/auto-discovery/newrelic/api-key"
}
variable "region" {
  default = "eu-west-1"
}

variable "nr_acc_id" {
  description = "New Relic account ID (an identifier, not a secret)"
  default     = 8049048
}

variable "nexus_password_param" {
  description = "SSM Parameter Store name that holds the Nexus admin password (created outside Terraform)"
  default     = "/auto-discovery/nexus/admin-password"
}

variable "sonarqube_password_param" {
  description = "SSM Parameter Store name that holds the SonarQube admin password (created outside Terraform)"
  default     = "/auto-discovery/sonarqube/admin-password"
}
