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

variable "existing_project_group" {
  type        = string
  nullable    = false
  sensitive   = false
  default     = ""
  description = "The name of an existing project group to place the project in, or a blank string to create a new project group."
}

data "octopusdeploy_library_variable_sets" "library_variable_set_octopub" {
  ids          = null
  partial_name = "Octopub"
  skip         = 0
  take         = 1
}

data "octopusdeploy_lifecycles" "default" {
  ids          = []
  partial_name = "Default Lifecycle"
  skip         = 0
  take         = 1
}

data "octopusdeploy_worker_pools" "workerpool_hosted_ubuntu" {
  partial_name = "Hosted Ubuntu"
  ids          = null
  skip         = 0
  take         = 1
}

resource "octopusdeploy_project_group" "project_group_infrastructure" {
  name        = "Infrastructure"
  description = "Builds the API Gateway."
  count       = length(var.existing_project_group) == 0 ? 1 : 0
}

data "octopusdeploy_project_groups" "existing_project_group" {
  partial_name = var.existing_project_group
  skip         = 0
  take         = 1
}

# The following octopusdeploy_git_credential resource and Terraform variables are used
# to create a Config-as-Code enabled project.

# resource "octopusdeploy_git_credential" "gitcredential" {
#   name     = "Octopub"
#   type     = "UsernamePassword"
#   username = "${var.gitusername}"
#   password = "${var.gitcredential}"
# }

# variable "gitusername" {
#   type        = string
#   nullable    = false
#   sensitive   = true
#   description = "The Git username"
# }

# variable "gitcredential" {
#   type        = string
#   nullable    = false
#   sensitive   = true
#   description = "The Git credentials"
# }

# variable "giturl" {
#   type        = string
#   nullable    = false
#   sensitive   = true
#   description = "The Git url"
# }

# variable "git_base_path" {
#   type        = string
#   nullable    = false
#   sensitive   = true
#   description = "The path where Config-as-Code files are saved"
#   default     = "products"
# }

# variable "cac_enabled" {
#   type        = string
#   nullable    = false
#   sensitive   = false
#   description = "Enables whether the project has Config-as-Code enabled"
#   default     = "true"
# }

resource "octopusdeploy_project" "project_api_gateway" {
  name                                 = "API Gateway"
  auto_create_release                  = false
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = "Deploys a shared API Gateway. This project is created and managed by the [Octopus Terraform provider](https://registry.terraform.io/providers/OctopusDeployLabs/octopusdeploy/latest/docs). The Terraform files can be found in the [GitHub repo](https://github.com/OctopusSolutionsEngineering/SalesEngineeringAwsLambda)."
  discrete_channel_release             = false
  is_disabled                          = false
  lifecycle_id                         = data.octopusdeploy_lifecycles.default.lifecycles[0].id
  project_group_id                     = length(var.existing_project_group) == 0 ? octopusdeploy_project_group.project_group_infrastructure[0].id : data.octopusdeploy_project_groups.existing_project_group.project_groups[0].id
  included_library_variable_sets       = [
    "${data.octopusdeploy_library_variable_sets.library_variable_set_octopub.library_variable_sets[0].id}"
  ]
  tenanted_deployment_participation = "Untenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = false
    exclude_unhealthy_targets       = false
    skip_machine_behavior           = "SkipUnavailableMachines"
  }

  is_version_controlled = false

  # This settings configure the project to use Config-as-Code
  # To enable CaC, comment out the "is_version_controlled" setting above,
  # and uncomment the following.

  # is_version_controlled                = var.cac_enabled

  # lifecycle {
  #   ignore_changes = [
  #     connectivity_policy,
  #   ]
  # }

  # git_library_persistence_settings {
  #   git_credential_id  = octopusdeploy_git_credential.gitcredential.id
  #   url                = var.giturl
  #   base_path          = ".octopus/${var.git_base_path}"
  #   default_branch     = "main"
  #   protected_branches = []
  # }
}

resource "octopusdeploy_deployment_process" "deployment_process_project_api_gateway" {
  # Ignoring the step field allows Terraform to create the project and steps, but
  # then ignore any changes made via the UI. This is useful when Terraform is used
  # to bootstrap the project but not "own" the configuration once it exists.

  # lifecycle {
  #   ignore_changes = [
  #     step,
  #   ]
  # }

  project_id = octopusdeploy_project.project_api_gateway.id

  step {
    condition           = "Success"
    name                = "Create API Gateway"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunCloudFormation"
      name                               = "Create API Gateway"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id
      properties                         = {
        "Octopus.Action.Aws.CloudFormation.Tags" = jsonencode([
          {
            "key"   = "OctopusTenantId"
            "value" = "#{if Octopus.Deployment.Tenant.Id}#{Octopus.Deployment.Tenant.Id}#{/if}#{unless Octopus.Deployment.Tenant.Id}untenanted#{/unless}"
          },
          {
            "key"   = "OctopusStepId"
            "value" = "#{Octopus.Step.Id}"
          },
          {
            "key"   = "OctopusRunbookRunId"
            "value" = "#{if Octopus.RunBookRun.Id}#{Octopus.RunBookRun.Id}#{/if}#{unless Octopus.RunBookRun.Id}none#{/unless}"
          },
          {
            "key"   = "OctopusDeploymentId"
            "value" = "#{if Octopus.Deployment.Id}#{Octopus.Deployment.Id}#{/if}#{unless Octopus.Deployment.Id}none#{/unless}"
          },
          {
            "key"   = "OctopusProjectId"
            "value" = "#{Octopus.Project.Id}"
          },
          {
            "key"   = "OctopusEnvironmentId"
            "value" = "#{Octopus.Environment.Id}"
          },
          {
            "value" = "#{Octopus.Environment.Name}"
            "key"   = "Environment"
          },
          {
            "value" = "#{Octopus.Project.Name}"
            "key"   = "DeploymentProject"
          },
        ])
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([])
        "Octopus.Action.Aws.Region"                           = "#{AWS.Region}"
        "Octopus.Action.Aws.CloudFormationStackName"          = "#{AWS.CloudFormation.ApiGatewayStack}"
        "Octopus.Action.Aws.CloudFormationTemplate"           = <<-EOT
        Resources:
          RestApi:
            Type: 'AWS::ApiGateway::RestApi'
            Properties:
              Description: Octopus Lambda Gateway
              Name: Octopub
              BinaryMediaTypes:
                - '*/*'
              EndpointConfiguration:
                Types:
                  - REGIONAL
          Health:
            Type: 'AWS::ApiGateway::Resource'
            Properties:
              RestApiId:
                Ref: RestApi
              ParentId:
                'Fn::GetAtt':
                  - RestApi
                  - RootResourceId
              PathPart: health
          Api:
            Type: 'AWS::ApiGateway::Resource'
            Properties:
              RestApiId:
                Ref: RestApi
              ParentId:
                'Fn::GetAtt':
                  - RestApi
                  - RootResourceId
              PathPart: api
          Web:
            Type: 'AWS::ApiGateway::Resource'
            Properties:
              RestApiId: !Ref RestApi
              ParentId: !GetAtt
                - RestApi
                - RootResourceId
              PathPart: '{proxy+}'
        Outputs:
          RestApi:
            Description: The REST API
            Value: !Ref RestApi
          RootResourceId:
            Description: ID of the resource exposing the root resource id
            Value:
              'Fn::GetAtt':
                - RestApi
                - RootResourceId
          Health:
            Description: ID of the resource exposing the health endpoints
            Value: !Ref Health
          Api:
            Description: ID of the resource exposing the api endpoint
            Value: !Ref Api
          Web:
            Description: ID of the resource exposing the web app frontend
            Value: !Ref Web
        EOT
        "Octopus.Action.Aws.TemplateSource"                   = "Inline"
        "Octopus.Action.Aws.WaitForCompletion"                = "True"
        "Octopus.Action.Aws.AssumeRole"                       = "False"
        "Octopus.Action.AwsAccount.Variable"                  = "AWS.Account"
        "Octopus.Action.AwsAccount.UseInstanceRole"           = "False"
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []
      features              = []
    }

    properties   = {}
    target_roles = []
  }
}