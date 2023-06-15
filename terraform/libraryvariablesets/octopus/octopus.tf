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

data "octopusdeploy_accounts" "aws_account" {
  account_type = "AmazonWebServicesAccount"
  ids          = []
  partial_name = "AWS Account"
  skip         = 0
  take         = 1
}

resource "octopusdeploy_library_variable_set" "library_variable_set_octopub" {
  name        = "Octopub"
  description = ""
}

resource "octopusdeploy_variable" "library_variable_set_octopub_aws_account_0" {
  owner_id     = octopusdeploy_library_variable_set.library_variable_set_octopub.id
  value        = data.octopusdeploy_accounts.aws_account.accounts[0].id
  name         = "AWS.Account"
  type         = "AmazonWebServicesAccount"
  is_sensitive = false

  scope {
    actions      = []
    channels     = []
    environments = []
    machines     = []
    roles        = null
    tenant_tags  = null
  }
  depends_on = []
}

variable "library_variable_set_octopub_aws_region_1" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The value associated with the variable AWS.Region"
  default     = "ap-southeast-2"
}

resource "octopusdeploy_variable" "library_variable_set_octopub_aws_region_1" {
  owner_id     = octopusdeploy_library_variable_set.library_variable_set_octopub.id
  value        = var.library_variable_set_octopub_aws_region_1
  name         = "AWS.Region"
  type         = "String"
  description  = ""
  is_sensitive = false

  scope {
    actions      = []
    channels     = []
    environments = []
    machines     = []
    roles        = null
    tenant_tags  = null
  }
  depends_on = []
}

variable "library_variable_set_octopub_aws_cloudformation_apigatewaystack_0" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The value associated with the variable AWS.CloudFormation.ApiGatewayStack"
  default     = "OctopubApiGateway-#{Octopus.Environment.Name}"
}

resource "octopusdeploy_variable" "library_variable_set_octopub_aws_cloudformation_apigatewaystack_0" {
  owner_id     = octopusdeploy_library_variable_set.library_variable_set_octopub.id
  value        = var.library_variable_set_octopub_aws_cloudformation_apigatewaystack_0
  name         = "AWS.CloudFormation.ApiGatewayStack"
  type         = "String"
  description  = ""
  is_sensitive = false

  scope {
    actions      = []
    channels     = []
    environments = []
    machines     = []
    roles        = null
    tenant_tags  = null
  }
  depends_on = []
}