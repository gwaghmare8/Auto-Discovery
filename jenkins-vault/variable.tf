variable "region" {
  default = "eu-west-1"
}


variable "domain" {

  description = "The domain name for our pet adoption project"
  type        = string
  default     = "gaurav-devops.site"
}

variable "nr_key_param" {
  description = "SSM Parameter Store name that holds the New Relic user API key"
  default     = "/auto-discovery/newrelic/api-key"
}

variable "nr_acc_id" {
  description = "New Relic account ID (an identifier, not a secret)"
  default     = 8049048
}

variable "vault_init_secret_name" {
  description = "Secrets Manager secret that holds the Vault root token and recovery keys"
  default     = "auto-discovery/vault-init"
}
