terraform {
  required_providers {
    octopusdeploy = { 
      source = "OctopusDeployLabs/octopusdeploy", version = "0.12.1" 
    }
  }
}

provider "octopusdeploy" {
  address  = var.octopus_server
  api_key  = var.octopus_apikey
  space_id = var.octopus_space_id
}

variable "octopus_server" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The URL of the Octopus server"
}

variable "octopus_apikey" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The API key used to access the Octopus server."
}

variable "octopus_space_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The ID of the Octopus space to populate."
}

resource "octopusdeploy_aws_account" "account_aws_account" {
  name                              = "AWS Account"
  description                       = ""
  environments                      = []
  tenant_tags                       = []
  tenants                           = null
  tenanted_deployment_participation = "Untenanted"
  access_key                        = var.account_aws_account_access
  secret_key                        = var.account_aws_account
}

variable "account_aws_account" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The AWS Account secret key"
}

variable "account_aws_account_access" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The AWS access key associated with the account AWS Account"
}