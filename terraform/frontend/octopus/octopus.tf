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
  npartial_nameame = "Hosted Ubuntu"
  ids              = null
  skip             = 0
  take             = 1
}

data "octopusdeploy_feeds" "sales_maven_feed" {
  feed_type    = "Maven"
  ids          = []
  partial_name = "Sales Maven Feed"
  skip         = 0
  take         = 1
}

resource "octopusdeploy_project_group" "project_group_frontend" {
  name        = "Octopub Frontend"
  description = "The Octopub web frontend"
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

resource "octopusdeploy_project" "project_frontend_webapp" {
  name                                 = "Frontend WebApp"
  auto_create_release                  = false
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = "Deploys the frontend webapp to Lambda."
  discrete_channel_release             = false
  is_disabled                          = false
  lifecycle_id                         = "${data.octopusdeploy_lifecycles.default.lifecycles[0].id}"
  project_group_id                     = length(var.existing_project_group) == 0 ? octopusdeploy_project_group.project_group_frontend[0].id : data.octopusdeploy_project_groups.existing_project_group.project_groups[0].id
  included_library_variable_sets       = [
    "${data.octopusdeploy_library_variable_sets.library_variable_set_octopub.library_variable_sets[0].id}"
  ]
  tenanted_deployment_participation    = "Untenanted"

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

resource "octopusdeploy_variable" "frontend_webapp_producthealthendpoint" {
  owner_id     = "${octopusdeploy_project.project_frontend_webapp.id}"
  value        = "https://#{Octopus.Action[Get Stack Outputs].Output.RestApi}.execute-api.ap-southeast-2.amazonaws.com/#{Octopus.Environment.Name}/health/products"
  name         = "productHealthEndpoint"
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

resource "octopusdeploy_variable" "frontend_webapp_productendpoint" {
  owner_id     = "${octopusdeploy_project.project_frontend_webapp.id}"
  value        = "https://#{Octopus.Action[Get Stack Outputs].Output.RestApi}.execute-api.ap-southeast-2.amazonaws.com/#{Octopus.Environment.Name}/api/products"
  name         = "productEndpoint"
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

resource "octopusdeploy_deployment_process" "deployment_process_project_frontend_webapp" {
  # Ignoring the step field allows Terraform to create the project and steps, but
  # then ignore any changes made via the UI. This is useful when Terraform is used
  # to bootstrap the project but not "own" the configuration once it exists.

  # lifecycle {
  #   ignore_changes = [
  #     step,
  #   ]
  # }

  project_id = "${octopusdeploy_project.project_frontend_webapp.id}"

  step {
    condition           = "Success"
    name                = "Get Stack Outputs"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunScript"
      name                               = "Get Stack Outputs"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Aws.AssumeRole"             = "False"
        "OctopusUseBundledTooling"                  = "False"
        "Octopus.Action.Aws.Region"                 = "#{AWS.Region}"
        "Octopus.Action.Script.ScriptBody"          = <<-EOF
        echo "Downloading Docker images"

        echo "##octopus[stdout-verbose]"

        docker pull amazon/aws-cli 2>&1

        # Alias the docker run commands
        shopt -s expand_aliases
        alias aws="docker run --rm -i -v $(pwd):/build -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli"

        echo "##octopus[stdout-default]"

        WEB_RESOURCE_ID=$(aws cloudformation \
            describe-stacks \
            --stack-name #{AWS.CloudFormation.ApiGatewayStack} \
            --query "Stacks[0].Outputs[?OutputKey=='Web'].OutputValue" \
            --output text)

        set_octopusvariable "Web" $${WEB_RESOURCE_ID}
        echo "Web Resource ID: $WEB_RESOURCE_ID"

        if [[ -z "$${WEB_RESOURCE_ID}" ]]; then
          echo "Run the API Gateway project first"
          exit 1
        fi

        REST_API=$(aws cloudformation \
            describe-stacks \
            --stack-name #{AWS.CloudFormation.ApiGatewayStack} \
            --query "Stacks[0].Outputs[?OutputKey=='RestApi'].OutputValue" \
            --output text)

        set_octopusvariable "RestApi" $${REST_API}
        echo "Rest API ID: $REST_API"

        if [[ -z "$${REST_API}" ]]; then
          echo "Run the API Gateway project first"
          exit 1
        fi

        ROOT_RESOURCE_ID=$(aws cloudformation \
            describe-stacks \
            --stack-name #{AWS.CloudFormation.ApiGatewayStack} \
            --query "Stacks[0].Outputs[?OutputKey=='RootResourceId'].OutputValue" \
            --output text)

        set_octopusvariable "RootResourceId" $${ROOT_RESOURCE_ID}
        echo "Root resource ID: $ROOT_RESOURCE_ID"

        if [[ -z "$${ROOT_RESOURCE_ID}" ]]; then
          echo "Run the API Gateway project first"
          exit 1
        fi
        EOF
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.AwsAccount.Variable"        = "AWS.Account"
        "Octopus.Action.Script.Syntax"              = "Bash"
        "Octopus.Action.Script.ScriptSource"        = "Inline"
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
  step {
    condition           = "Success"
    name                = "Create S3 Bucket"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunCloudFormation"
      name                               = "Create S3 Bucket"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.AwsAccount.UseInstanceRole"           = "False"
        "Octopus.Action.Aws.CloudFormationStackName"          = "OctopubFrontendS3Bucket-#{Octopus.Environment.Name}"
        "Octopus.Action.Aws.AssumeRole"                       = "False"
        "Octopus.Action.Aws.TemplateSource"                   = "Inline"
        "Octopus.Action.Aws.WaitForCompletion"                = "True"
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([])
        "Octopus.Action.AwsAccount.Variable"                  = "AWS.Account"
        "Octopus.Action.Aws.Region"                           = "#{AWS.Region}"
        "Octopus.Action.Aws.CloudFormation.Tags"              = jsonencode([
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
        "Octopus.Action.Aws.CloudFormationTemplate"  = <<-EOF
        AWSTemplateFormatVersion: 2010-09-09
        Resources:
          S3Bucket:
            Type: AWS::S3::Bucket
            Properties:
              AccessControl: PublicRead
              WebsiteConfiguration:
                IndexDocument: index.html
                ErrorDocument: error.html
            DeletionPolicy: Retain
          BucketPolicy:
            Type: AWS::S3::BucketPolicy
            Properties:
              PolicyDocument:
                Id: MyPolicy
                Version: 2012-10-17
                Statement:
                  - Sid: PublicReadForGetBucketObjects
                    Effect: Allow
                    Principal: '*'
                    Action: 's3:GetObject'
                    Resource: !Join
                      - ''
                      - - 'arn:aws:s3:::'
                        - !Ref S3Bucket
                        - /*
              Bucket: !Ref S3Bucket
        Outputs:
          Bucket:
            Value: !Ref S3Bucket
            Description: URL for website hosted on S3
          WebsiteURL:
            Value: !GetAtt
              - S3Bucket
              - WebsiteURL
            Description: URL for website hosted on S3
          S3BucketSecureURL:
            Value: !Join
              - ''
              - - 'https://'
                - !GetAtt
                  - S3Bucket
                  - DomainName
            Description: Name of S3 bucket to hold website content
        EOF 
      }
      environments                       = []
      excluded_environments              = []
      channels                           = []
      tenant_tags                        = []
      features                           = []
    }

    properties   = {}
    target_roles = []
  }
  step {
    condition           = "Success"
    name                = "Upload Frontend"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsUploadS3"
      name                               = "Upload Frontend"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Aws.S3.TargetMode" = "FileSelections"
        "Octopus.Action.Package.DownloadOnTentacle" = "False"
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.Aws.S3.FileSelections" = jsonencode([
        {
        "bucketKeyPrefix" = "#{Octopus.Action[Upload Frontend].Package[].PackageId}.#{Octopus.Action[Upload Frontend].Package[].PackageVersion}/"
        "metadata" = []
        "pattern" = "**/*"
        "bucketKeyBehaviour" = "Custom"
        "path" = ""
        "bucketKey" = ""
        "cannedAcl" = "private"
        "performStructuredVariableSubstitution" = "False"
        "autoFocus" = "true"
        "performVariableSubstitution" = "False"
        "storageClass" = "STANDARD"
        "structuredVariableSubstitutionPatterns" = "config.json"
        "tags" = []
        "type" = "MultipleFiles"
                },
        ])
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.Aws.S3.BucketName" = "#{Octopus.Action[Create S3 bucket].Output.AwsOutputs[Bucket]}"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
      }
      environments                       = []
      excluded_environments              = []
      channels                           = []
      tenant_tags                        = []

      primary_package {
        package_id           = "com.octopus:frontend-webapp-static"
        acquisition_location = "Server"
        feed_id              = "${data.octopusdeploy_feeds.sales_maven_feed.feeds[0].id}"
        properties           = { SelectionMode = "immediate" }
      }

      features = []
    }

    properties   = {}
    target_roles = []
  }
  step {
    condition           = "Success"
    name                = "Proxy with API Gateway"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunCloudFormation"
      name                               = "Proxy with API Gateway"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.Aws.TemplateSource" = "Inline"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Aws.CloudFormationTemplate" = <<-EOF
        Parameters:
          EnvironmentName:
            Type: String
            Default: '#{Octopus.Environment.Name | Replace " .*" ""}'
          RestApi:
            Type: String
          RootResourceId:
            Type: String
          ResourceId:
            Type: String
          PackageVersion:
            Type: String
          PackageId:
            Type: String
          BucketName:
            Type: String
          SubPath:
            Type: String
        Resources:
          FrontendMethodOne:
            Type: 'AWS::ApiGateway::Method'
            Properties:
              AuthorizationType: NONE
              HttpMethod: GET
              Integration:
                ContentHandling: CONVERT_TO_TEXT
                IntegrationHttpMethod: GET
                TimeoutInMillis: 20000
                Type: HTTP
                Uri:
                  'Fn::Join':
                    - ''
                    - - 'http://'
                      - Ref: BucketName
                      - .s3-website-ap-southeast-2.amazonaws.com/
                      - Ref: PackageId
                      - .
                      - Ref: PackageVersion
                      - /index.html
                PassthroughBehavior: WHEN_NO_MATCH
                RequestTemplates:
                  image/png: ''
                IntegrationResponses:
                  - StatusCode: '200'
                    ResponseParameters:
                      method.response.header.Content-Type: integration.response.header.Content-Type
                      method.response.header.X-Content-Type-Options: '''nosniff'''
                      method.response.header.X-Frame-Options: '''DENY'''
                      method.response.header.X-XSS-Protection: '''1; mode=block'''
                      method.response.header.Referrer-Policy: '''no-referrer'''
                      method.response.header.Permissions-Policy: "'accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), cross-origin-isolated=(), display-capture=(), document-domain=(), encrypted-media=(), execution-while-not-rendered=(), execution-while-out-of-viewport=(), fullscreen=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), navigation-override=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), sync-xhr=(), usb=(), web-share=(), xr-spatial-tracking=(), clipboard-read=(), clipboard-write=*, gamepad=(), speaker-selection=(), conversion-measurement=(), focus-without-user-activation=(), hid=(), idle-detection=(), interest-cohort=(), serial=(), sync-script=(), trust-token-redemption=(), window-placement=(), vertical-scroll=()'"
                      method.response.header.Content-Security-Policy: "'frame-ancestors 'none'; form-action 'none'; base-uri 'none'; object-src 'none'; default-src 'self' 'unsafe-inline' *.google-analytics.com *.amazonaws.com *.youtube.com oc.to; script-src 'self' 'unsafe-inline' *.google-analytics.com *.googletagmanager.com; style-src * 'unsafe-inline'; img-src *; font-src *'"
                      method.response.header.Strict-Transport-Security: '''max-age=15768000'''
              MethodResponses:
                - ResponseModels:
                    text/html: Empty
                    text/css: Empty
                  StatusCode: '200'
                  ResponseParameters:
                    method.response.header.Content-Type: true
                    method.response.header.Content-Security-Policy: true
                    method.response.header.X-Content-Type-Options: true
                    method.response.header.X-Frame-Options: true
                    method.response.header.X-XSS-Protection: true
                    method.response.header.Referrer-Policy: true
                    method.response.header.Permissions-Policy: true
                    method.response.header.Strict-Transport-Security: true
              ResourceId:
                Ref: RootResourceId
              RestApiId:
                Ref: RestApi
          FrontendMethodTwo:
            Type: 'AWS::ApiGateway::Method'
            Properties:
              AuthorizationType: NONE
              HttpMethod: GET
              RequestParameters:
                method.request.path.proxy: true
              Integration:
                ContentHandling: CONVERT_TO_TEXT
                IntegrationHttpMethod: GET
                TimeoutInMillis: 20000
                Type: HTTP
                Uri:
                  'Fn::Join':
                    - ''
                    - - 'http://'
                      - Ref: BucketName
                      - .s3-website-ap-southeast-2.amazonaws.com/
                      - Ref: PackageId
                      - .
                      - Ref: PackageVersion
                      - '/{proxy}'
                PassthroughBehavior: WHEN_NO_MATCH
                RequestTemplates:
                  image/png: ''
                IntegrationResponses:
                  - StatusCode: '200'
                    ResponseParameters:
                      method.response.header.Content-Type: integration.response.header.Content-Type
                      method.response.header.X-Content-Type-Options: '''nosniff'''
                      method.response.header.X-Frame-Options: '''DENY'''
                      method.response.header.X-XSS-Protection: '''1; mode=block'''
                      method.response.header.Referrer-Policy: '''no-referrer'''
                      method.response.header.Permissions-Policy: "'accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), cross-origin-isolated=(), display-capture=(), document-domain=(), encrypted-media=(), execution-while-not-rendered=(), execution-while-out-of-viewport=(), fullscreen=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), navigation-override=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), sync-xhr=(), usb=(), web-share=(), xr-spatial-tracking=(), clipboard-read=(), clipboard-write=*, gamepad=(), speaker-selection=(), conversion-measurement=(), focus-without-user-activation=(), hid=(), idle-detection=(), interest-cohort=(), serial=(), sync-script=(), trust-token-redemption=(), window-placement=(), vertical-scroll=()'"
                      method.response.header.Content-Security-Policy: "'frame-ancestors 'none'; form-action 'none'; base-uri 'none'; object-src 'none'; default-src 'self' 'unsafe-inline' *.google-analytics.com *.amazonaws.com *.youtube.com oc.to; script-src 'self' 'unsafe-inline' *.google-analytics.com *.googletagmanager.com; style-src * 'unsafe-inline'; img-src *; font-src *'"
                      method.response.header.Strict-Transport-Security: '''max-age=15768000'''
                  - StatusCode: '307'
                    SelectionPattern: '307'
                    ResponseParameters:
                      method.response.header.Location: integration.response.header.Location
                RequestParameters:
                  integration.request.path.proxy: method.request.path.proxy
              MethodResponses:
                - ResponseModels:
                    text/html: Empty
                    text/css: Empty
                  StatusCode: '200'
                  ResponseParameters:
                    method.response.header.Content-Type: true
                    method.response.header.Content-Security-Policy: true
                    method.response.header.X-Content-Type-Options: true
                    method.response.header.X-Frame-Options: true
                    method.response.header.X-XSS-Protection: true
                    method.response.header.Referrer-Policy: true
                    method.response.header.Permissions-Policy: true
                    method.response.header.Strict-Transport-Security: true
                - ResponseModels:
                    text/html: Empty
                    text/css: Empty
                  StatusCode: '307'
                  ResponseParameters:
                    method.response.header.Location: true
              ResourceId:
                Ref: ResourceId
              RestApiId:
                Ref: RestApi
          'Deployment#{Octopus.Deployment.Id | Replace -}':
            Type: 'AWS::ApiGateway::Deployment'
            Properties:
              RestApiId:
                Ref: RestApi
            DependsOn:
              - FrontendMethodOne
              - FrontendMethodTwo
        Outputs:
          DeploymentId:
            Description: The deployment id
            Value:
              Ref: 'Deployment#{Octopus.Deployment.Id | Replace -}'
          DownstreamService:
            Description: The function that was configured to accept traffic.
            Value:
              'Fn::Join':
                - ''
                - - 'http://'
                  - Ref: BucketName
                  - .s3-website-ap-southeast-2.amazonaws.com/
                  - Ref: PackageId
                  - .
                  - Ref: PackageVersion
                  - '/{proxy}'
        EOF
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubFrontendApiGateway-#{Octopus.Environment.Name}"
        "Octopus.Action.Aws.AssumeRole"              = "False"
        "Octopus.Action.Aws.CloudFormation.Tags"     = jsonencode([
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
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([
          {
            "ParameterKey"   = "EnvironmentName"
            "ParameterValue" = "#{Octopus.Environment.Name}"
          },
          {
            "ParameterKey"   = "RestApi"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RestApi}"
          },
          {
            "ParameterKey"   = "RootResourceId"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RootResourceId}"
          },
          {
            "ParameterKey"   = "ResourceId"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.Web}"
          },
          {
            "ParameterKey"   = "PackageVersion"
            "ParameterValue" = "#{Octopus.Action[Upload Frontend].Package[].PackageVersion}"
          },
          {
            "ParameterKey"   = "PackageId"
            "ParameterValue" = "#{Octopus.Action[Upload Frontend].Package[].PackageId}"
          },
          {
            "ParameterKey"   = "BucketName"
            "ParameterValue" = "#{Octopus.Action[Create S3 bucket].Output.AwsOutputs[Bucket]}"
          },
          {
            "ParameterKey"   = "SubPath"
            "ParameterValue" = ""
          },
        ])
        "Octopus.Action.Aws.Region"            = "#{AWS.Region}"
        "Octopus.Action.Aws.WaitForCompletion" = "True"
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
  step {
    condition           = "Success"
    name                = "Update Stage"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunCloudFormation"
      name                               = "Update Stage"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Aws.Region"                           = "#{AWS.Region}"
        "Octopus.Action.Aws.TemplateSource"                   = "Inline"
        "Octopus.Action.AwsAccount.Variable"                  = "AWS.Account"
        "Octopus.Action.Aws.AssumeRole"                       = "False"
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([
          {
            "ParameterKey"   = "EnvironmentName"
            "ParameterValue" = "#{Octopus.Environment.Name}"
          },
          {
            "ParameterKey"   = "DeploymentId"
            "ParameterValue" = "#{Octopus.Action[Proxy with API Gateway].Output.AwsOutputs[DeploymentId]}"
          },
          {
            "ParameterKey"   = "ApiGatewayId"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RestApi}"
          },
        ])
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubApiGatewayStage-#{Octopus.Environment.Name}"
        "Octopus.Action.Aws.CloudFormationTemplate"  = <<-EOF
        Parameters:
          EnvironmentName:
            Type: String
            Default: '#{Octopus.Environment.Name | Replace " .*" ""}'
          DeploymentId:
            Type: String
          ApiGatewayId:
            Type: String
        Resources:
          Stage:
            Type: 'AWS::ApiGateway::Stage'
            Properties:
              DeploymentId: !Sub '$${DeploymentId}'
              RestApiId: !Sub '$${ApiGatewayId}'
              StageName: !Sub '$${EnvironmentName}'
        Outputs:
          DnsName:
            Value:
              'Fn::Join':
                - ''
                - - Ref: ApiGatewayId
                  - .execute-api.
                  - Ref: 'AWS::Region'
                  - .amazonaws.com
          StageURL:
            Description: The url of the stage
            Value: !Join
              - ''
              - - 'https://'
                - !Ref ApiGatewayId
                - .execute-api.
                - !Ref 'AWS::Region'
                - .amazonaws.com/
                - !Ref Stage
                - /
        EOF
        "Octopus.Action.Aws.WaitForCompletion"       = "True"
        "Octopus.Action.Aws.CloudFormation.Tags"     = jsonencode([
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
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
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
  step {
    condition           = "Success"
    name                = "Get Stage Outputs"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunScript"
      name                               = "Get Stage Outputs"
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Script.Syntax"              = "Bash"
        "Octopus.Action.Aws.Region"                 = "#{AWS.Region}"
        "OctopusUseBundledTooling"                  = "False"
        "Octopus.Action.Script.ScriptBody"          = <<-EOF
        echo "Downloading Docker images"

        echo "##octopus[stdout-verbose]"

        docker pull amazon/aws-cli 2>&1

        # Alias the docker run commands
        shopt -s expand_aliases
        alias aws="docker run --rm -i -v $(pwd):/build -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli"

        echo "##octopus[stdout-default]"

        STAGE_URL=$(aws cloudformation \
            describe-stacks \
            --stack-name "OctopubApiGatewayStage-#{Octopus.Environment.Name | Replace " .*" ""}" \
            --query "Stacks[0].Outputs[?OutputKey=='StageURL'].OutputValue" \
            --output text)

        set_octopusvariable "StageURL" $${STAGE_URL}
        echo "Stage URL: $STAGE_URL"

        DNS_NAME=$(aws cloudformation \
            describe-stacks \
            --stack-name "OctopubApiGatewayStage-#{Octopus.Environment.Name | Replace " .*" ""}" \
            --query "Stacks[0].Outputs[?OutputKey=='DnsName'].OutputValue" \
            --output text)

        set_octopusvariable "DNSName" $${DNS_NAME}
        echo "DNS Name: $DNS_NAME"

        write_highlight "Open [$${STAGE_URL}index.html]($${STAGE_URL}index.html) to view the frontend web app."
        EOF
        "Octopus.Action.AwsAccount.Variable"        = "AWS.Account"
        "Octopus.Action.Script.ScriptSource"        = "Inline"
        "Octopus.Action.Aws.AssumeRole"             = "False"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
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