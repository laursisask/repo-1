terraform {
  backend "s3" {
  }
}

terraform {
  required_providers {
    octopusdeploy = { 
      source = "OctopusDeployLabs/octopusdeploy", version = "0.12.1" 
    }
  }
}

provider "octopusdeploy" {
  address  = "${var.octopus_server}"
  api_key  = "${var.octopus_apikey}"
  space_id = "${var.octopus_space_id}"
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

module "octopus" {
  source = "../octopus"
  octopus_server = var.octopus_server
  octopus_apikey = var.octopus_apikey
  octopus_space_id = var.octopus_space_id
}