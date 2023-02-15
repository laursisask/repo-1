terraform {
  required_providers {
    octopusdeploy = { source = "OctopusDeployLabs/octopusdeploy", version = "0.10.3" }
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
  description = "The URL of the Octopus server e.g. https://myinstance.octopus.app."
}

variable "octopus_apikey" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "The API key used to access the Octopus server. See https://octopus.com/docs/octopus-rest-api/how-to-create-an-api-key for details on creating an API key."
}

variable "octopus_space_id" {
  type        = string
  nullable    = false
  sensitive   = false
  description = "The ID of the Octopus space to populate."
}

data "octopusdeploy_environments" "environment_production" {
  ids          = null
  partial_name = "Production"
  skip         = 0
  take         = 1
}

data "octopusdeploy_environments" "environment_development" {
  ids          = null
  partial_name = "Development"
  skip         = 0
  take         = 1
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
  name = "Hosted Ubuntu"
  ids  = null
  skip = 0
  take = 1
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
}

resource "octopusdeploy_project" "project_frontend_webapp" {
  name                                 = "Frontend WebApp"
  auto_create_release                  = false
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = "Deploys the frontend webapp to Lambda."
  discrete_channel_release             = false
  is_disabled                          = false
  is_version_controlled                = false
  lifecycle_id                         = "${data.octopusdeploy_lifecycles.default.lifecycles[0].id}"
  project_group_id                     = "${octopusdeploy_project_group.project_group_frontend.id}"
  included_library_variable_sets       = ["${data.octopusdeploy_library_variable_sets.library_variable_set_octopub.library_variable_sets[0].id}"]
  tenanted_deployment_participation    = "Untenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = false
    exclude_unhealthy_targets       = false
    skip_machine_behavior           = "SkipUnavailableMachines"
  }
}

resource "octopusdeploy_deployment_process" "deployment_process_project_frontend_webapp" {
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
        "Octopus.Action.Aws.AssumeRole" = "False"
        "OctopusUseBundledTooling" = "False"
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Script.ScriptBody" = "echo \"Downloading Docker images\"\n\necho \"##octopus[stdout-verbose]\"\n\ndocker pull amazon/aws-cli 2\u003e\u00261\n\n# Alias the docker run commands\nshopt -s expand_aliases\nalias aws=\"docker run --rm -i -v $(pwd):/build -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli\"\n\necho \"##octopus[stdout-default]\"\n\nWEB_RESOURCE_ID=$(aws cloudformation \\\n    describe-stacks \\\n    --stack-name #{AWS.CloudFormation.ApiGatewayStack} \\\n    --query \"Stacks[0].Outputs[?OutputKey=='Web'].OutputValue\" \\\n    --output text)\n\nset_octopusvariable \"Web\" $${WEB_RESOURCE_ID}\necho \"Web Resource ID: $WEB_RESOURCE_ID\"\n\nif [[ -z \"$${WEB_RESOURCE_ID}\" ]]; then\n  echo \"Run the API Gateway project first\"\n  exit 1\nfi\n\nREST_API=$(aws cloudformation \\\n    describe-stacks \\\n    --stack-name #{AWS.CloudFormation.ApiGatewayStack} \\\n    --query \"Stacks[0].Outputs[?OutputKey=='RestApi'].OutputValue\" \\\n    --output text)\n\nset_octopusvariable \"RestApi\" $${REST_API}\necho \"Rest API ID: $REST_API\"\n\nif [[ -z \"$${REST_API}\" ]]; then\n  echo \"Run the API Gateway project first\"\n  exit 1\nfi\n\nROOT_RESOURCE_ID=$(aws cloudformation \\\n    describe-stacks \\\n    --stack-name #{AWS.CloudFormation.ApiGatewayStack} \\\n    --query \"Stacks[0].Outputs[?OutputKey=='RootResourceId'].OutputValue\" \\\n    --output text)\n\nset_octopusvariable \"RootResourceId\" $${ROOT_RESOURCE_ID}\necho \"Root resource ID: $ROOT_RESOURCE_ID\"\n\nif [[ -z \"$${ROOT_RESOURCE_ID}\" ]]; then\n  echo \"Run the API Gateway project first\"\n  exit 1\nfi\n"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Script.Syntax" = "Bash"
        "Octopus.Action.Script.ScriptSource" = "Inline"
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
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubFrontendS3Bucket-#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.Aws.TemplateSource" = "Inline"
        "Octopus.Action.Aws.WaitForCompletion" = "True"
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([
        {
        "ParameterKey" = "Hostname"
        "ParameterValue" = "#{WebApp.Hostname}"
                },
        ])
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.CloudFormation.Tags" = jsonencode([
        {
        "value" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
        "key" = "Environment"
                },
        {
        "value" = "Frontend_WebApp"
        "key" = "DeploymentProject"
                },
        ])
        "Octopus.Action.Aws.CloudFormationTemplate" = "AWSTemplateFormatVersion: 2010-09-09\nParameters:\n  Hostname:\n    Type: String\nResources:\n  S3Bucket:\n    Type: AWS::S3::Bucket\n    Properties:\n      AccessControl: PublicRead\n      WebsiteConfiguration:\n        IndexDocument: index.html\n        ErrorDocument: error.html\n        RoutingRules:\n        - RoutingRuleCondition:\n           HttpErrorCodeReturnedEquals: '404'\n          RedirectRule:\n            ReplaceKeyWith: index.html\n            HostName: !Ref Hostname\n            Protocol: https\n    DeletionPolicy: Retain\n  BucketPolicy:\n    Type: AWS::S3::BucketPolicy\n    Properties:\n      PolicyDocument:\n        Id: MyPolicy\n        Version: 2012-10-17\n        Statement:\n          - Sid: PublicReadForGetBucketObjects\n            Effect: Allow\n            Principal: '*'\n            Action: 's3:GetObject'\n            Resource: !Join\n              - ''\n              - - 'arn:aws:s3:::'\n                - !Ref S3Bucket\n                - /*\n      Bucket: !Ref S3Bucket\nOutputs:\n  Bucket:\n    Value: !Ref S3Bucket\n    Description: URL for website hosted on S3\n  WebsiteURL:\n    Value: !GetAtt\n      - S3Bucket\n      - WebsiteURL\n    Description: URL for website hosted on S3\n  S3BucketSecureURL:\n    Value: !Join\n      - ''\n      - - 'https://'\n        - !GetAtt\n          - S3Bucket\n          - DomainName\n    Description: Name of S3 bucket to hold website content\n"
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
        "Octopus.Action.Aws.CloudFormationTemplate" = "Parameters:\n  EnvironmentName:\n    Type: String\n    Default: '#{Octopus.Environment.Name | Replace \" .*\" \"\"}'\n  RestApi:\n    Type: String\n  RootResourceId:\n    Type: String\n  ResourceId:\n    Type: String\n  PackageVersion:\n    Type: String\n  PackageId:\n    Type: String\n  BucketName:\n    Type: String\n  SubPath:\n    Type: String\nConditions:\n  IsFeatureBranch:\n    'Fn::Not':\n      - 'Fn::Equals':\n          - Ref: SubPath\n          - ''\nResources:\n  BranchResource:\n    Type: 'AWS::ApiGateway::Resource'\n    Condition: IsFeatureBranch\n    Properties:\n      RestApiId:\n        Ref: RestApi\n      ParentId:\n        Ref: RootResourceId\n      PathPart:\n        Ref: SubPath\n  BranchResourceProxy:\n    Type: 'AWS::ApiGateway::Resource'\n    Condition: IsFeatureBranch\n    Properties:\n      RestApiId:\n        Ref: RestApi\n      ParentId:\n        Ref: BranchResource\n      PathPart: '{proxy+}'\n  FrontendMethodOne:\n    Type: 'AWS::ApiGateway::Method'\n    Properties:\n      AuthorizationType: NONE\n      HttpMethod: ANY\n      Integration:\n        ContentHandling: CONVERT_TO_TEXT\n        IntegrationHttpMethod: GET\n        TimeoutInMillis: 20000\n        Type: HTTP\n        Uri:\n          'Fn::Join':\n            - ''\n            - - 'http://'\n              - Ref: BucketName\n              - .s3-website-ap-southeast-2.amazonaws.com/\n              - Ref: PackageId\n              - .\n              - Ref: PackageVersion\n              - /index.html\n        PassthroughBehavior: WHEN_NO_MATCH\n        RequestTemplates:\n          image/png: ''\n        IntegrationResponses:\n          - StatusCode: '200'\n            ResponseParameters:\n              method.response.header.Content-Type: integration.response.header.Content-Type\n              method.response.header.X-Content-Type-Options: '''nosniff'''\n              method.response.header.X-Frame-Options: '''DENY'''\n              method.response.header.X-XSS-Protection: '''1; mode=block'''\n              method.response.header.Referrer-Policy: '''no-referrer'''\n              method.response.header.Permissions-Policy: \"'accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), cross-origin-isolated=(), display-capture=(), document-domain=(), encrypted-media=(), execution-while-not-rendered=(), execution-while-out-of-viewport=(), fullscreen=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), navigation-override=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), sync-xhr=(), usb=(), web-share=(), xr-spatial-tracking=(), clipboard-read=(), clipboard-write=*, gamepad=(), speaker-selection=(), conversion-measurement=(), focus-without-user-activation=(), hid=(), idle-detection=(), interest-cohort=(), serial=(), sync-script=(), trust-token-redemption=(), window-placement=(), vertical-scroll=()'\"\n              method.response.header.Content-Security-Policy: \"'frame-ancestors 'none'; form-action 'none'; base-uri 'none'; object-src 'none'; default-src 'self' 'unsafe-inline' *.google-analytics.com *.amazonaws.com *.youtube.com oc.to; script-src 'self' 'unsafe-inline' *.google-analytics.com *.googletagmanager.com; style-src * 'unsafe-inline'; img-src *; font-src *'\"\n              method.response.header.Strict-Transport-Security: '''max-age=15768000'''\n      MethodResponses:\n        - ResponseModels:\n            text/html: Empty\n            text/css: Empty\n          StatusCode: '200'\n          ResponseParameters:\n            method.response.header.Content-Type: true\n            method.response.header.Content-Security-Policy: true\n            method.response.header.X-Content-Type-Options: true\n            method.response.header.X-Frame-Options: true\n            method.response.header.X-XSS-Protection: true\n            method.response.header.Referrer-Policy: true\n            method.response.header.Permissions-Policy: true\n            method.response.header.Strict-Transport-Security: true\n      ResourceId:\n        'Fn::If':\n          - IsFeatureBranch\n          - Ref: BranchResource\n          - Ref: RootResourceId\n      RestApiId:\n        Ref: RestApi\n  FrontendMethodTwo:\n    Type: 'AWS::ApiGateway::Method'\n    Properties:\n      AuthorizationType: NONE\n      HttpMethod: ANY\n      RequestParameters:\n        method.request.path.proxy: true\n      Integration:\n        ContentHandling: CONVERT_TO_TEXT\n        IntegrationHttpMethod: GET\n        TimeoutInMillis: 20000\n        Type: HTTP\n        Uri:\n          'Fn::Join':\n            - ''\n            - - 'http://'\n              - Ref: BucketName\n              - .s3-website-ap-southeast-2.amazonaws.com/\n              - Ref: PackageId\n              - .\n              - Ref: PackageVersion\n              - '/{proxy}'\n        PassthroughBehavior: WHEN_NO_MATCH\n        RequestTemplates:\n          image/png: ''\n        IntegrationResponses:\n          - StatusCode: '200'\n            ResponseParameters:\n              method.response.header.Content-Type: integration.response.header.Content-Type\n              method.response.header.X-Content-Type-Options: '''nosniff'''\n              method.response.header.X-Frame-Options: '''DENY'''\n              method.response.header.X-XSS-Protection: '''1; mode=block'''\n              method.response.header.Referrer-Policy: '''no-referrer'''\n              method.response.header.Permissions-Policy: \"'accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), cross-origin-isolated=(), display-capture=(), document-domain=(), encrypted-media=(), execution-while-not-rendered=(), execution-while-out-of-viewport=(), fullscreen=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), navigation-override=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), sync-xhr=(), usb=(), web-share=(), xr-spatial-tracking=(), clipboard-read=(), clipboard-write=*, gamepad=(), speaker-selection=(), conversion-measurement=(), focus-without-user-activation=(), hid=(), idle-detection=(), interest-cohort=(), serial=(), sync-script=(), trust-token-redemption=(), window-placement=(), vertical-scroll=()'\"\n              method.response.header.Content-Security-Policy: \"'frame-ancestors 'none'; form-action 'none'; base-uri 'none'; object-src 'none'; default-src 'self' 'unsafe-inline' *.google-analytics.com *.amazonaws.com *.youtube.com oc.to; script-src 'self' 'unsafe-inline' *.google-analytics.com *.googletagmanager.com; style-src * 'unsafe-inline'; img-src *; font-src *'\"\n              method.response.header.Strict-Transport-Security: '''max-age=15768000'''\n          - StatusCode: '307'\n            SelectionPattern: '307'\n            ResponseParameters:\n              method.response.header.Location: integration.response.header.Location\n        RequestParameters:\n          integration.request.path.proxy: method.request.path.proxy\n      MethodResponses:\n        - ResponseModels:\n            text/html: Empty\n            text/css: Empty\n          StatusCode: '200'\n          ResponseParameters:\n            method.response.header.Content-Type: true\n            method.response.header.Content-Security-Policy: true\n            method.response.header.X-Content-Type-Options: true\n            method.response.header.X-Frame-Options: true\n            method.response.header.X-XSS-Protection: true\n            method.response.header.Referrer-Policy: true\n            method.response.header.Permissions-Policy: true\n            method.response.header.Strict-Transport-Security: true\n        - ResponseModels:\n            text/html: Empty\n            text/css: Empty\n          StatusCode: '307'\n          ResponseParameters:\n            method.response.header.Location: true\n      ResourceId:\n        'Fn::If':\n          - IsFeatureBranch\n          - Ref: BranchResourceProxy\n          - Ref: ResourceId\n      RestApiId:\n        Ref: RestApi\n  'Deployment#{Octopus.Deployment.Id | Replace -}':\n    Type: 'AWS::ApiGateway::Deployment'\n    Properties:\n      RestApiId:\n        Ref: RestApi\n    DependsOn:\n      - FrontendMethodOne\n      - FrontendMethodTwo\nOutputs:\n  DeploymentId:\n    Description: The deployment id\n    Value:\n      Ref: 'Deployment#{Octopus.Deployment.Id | Replace -}'\n  DownstreamService:\n    Description: The function that was configured to accept traffic.\n    Value:\n      'Fn::Join':\n        - ''\n        - - 'http://'\n          - Ref: BucketName\n          - .s3-website-ap-southeast-2.amazonaws.com/\n          - Ref: PackageId\n          - .\n          - Ref: PackageVersion\n          - '/{proxy}'\n"
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubFrontendApiGateway-#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.Aws.CloudFormation.Tags" = jsonencode([
        {
        "key" = "Environment"
        "value" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
                },
        {
        "key" = "DeploymentProject"
        "value" = "Frontend_WebApp"
                },
        ])
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([
        {
        "ParameterKey" = "EnvironmentName"
        "ParameterValue" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
                },
        {
        "ParameterKey" = "RestApi"
        "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RestApi}"
                },
        {
        "ParameterKey" = "RootResourceId"
        "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RootResourceId}"
                },
        {
        "ParameterKey" = "ResourceId"
        "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.Web}"
                },
        {
        "ParameterKey" = "PackageVersion"
        "ParameterValue" = "#{Octopus.Action[Upload Frontend].Package[].PackageVersion}"
                },
        {
        "ParameterKey" = "PackageId"
        "ParameterValue" = "#{Octopus.Action[Upload Frontend].Package[].PackageId}"
                },
        {
        "ParameterKey" = "BucketName"
        "ParameterValue" = "#{Octopus.Action[Create S3 bucket].Output.AwsOutputs[Bucket]}"
                },
        {
        "ParameterKey" = "SubPath"
        "ParameterValue" = ""
                },
        ])
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.WaitForCompletion" = "True"
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
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.TemplateSource" = "Inline"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([
        {
        "ParameterKey" = "EnvironmentName"
        "ParameterValue" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
                },
        {
        "ParameterKey" = "DeploymentId"
        "ParameterValue" = "#{Octopus.Action[Proxy with API Gateway].Output.AwsOutputs[DeploymentId]}"
                },
        {
        "ParameterKey" = "ApiGatewayId"
        "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RestApi}"
                },
        ])
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubApiGatewayStage-#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
        "Octopus.Action.Aws.CloudFormationTemplate" = "Parameters:\n  EnvironmentName:\n    Type: String\n    Default: '#{Octopus.Environment.Name | Replace \" .*\" \"\"}'\n  DeploymentId:\n    Type: String\n  ApiGatewayId:\n    Type: String\nResources:\n  Stage:\n    Type: 'AWS::ApiGateway::Stage'\n    Properties:\n      DeploymentId: !Sub '$${DeploymentId}'\n      RestApiId: !Sub '$${ApiGatewayId}'\n      StageName: !Sub '$${EnvironmentName}'\n      Variables:\n        indexPage: !Sub /index.html\nOutputs:\n  DnsName:\n    Value:\n      'Fn::Join':\n        - ''\n        - - Ref: ApiGatewayId\n          - .execute-api.\n          - Ref: 'AWS::Region'\n          - .amazonaws.com\n  StageURL:\n    Description: The url of the stage\n    Value: !Join\n      - ''\n      - - 'https://'\n        - !Ref ApiGatewayId\n        - .execute-api.\n        - !Ref 'AWS::Region'\n        - .amazonaws.com/\n        - !Ref Stage\n        - /\n"
        "Octopus.Action.Aws.WaitForCompletion" = "True"
        "Octopus.Action.Aws.CloudFormation.Tags" = jsonencode([
        {
        "value" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
        "key" = "Environment"
                },
        {
        "key" = "DeploymentProject"
        "value" = "Frontend_WebApp"
                },
        ])
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
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
        "Octopus.Action.Script.Syntax" = "Bash"
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "OctopusUseBundledTooling" = "False"
        "Octopus.Action.Script.ScriptBody" = "echo \"Downloading Docker images\"\n\necho \"##octopus[stdout-verbose]\"\n\ndocker pull amazon/aws-cli 2\u003e\u00261\n\n# Alias the docker run commands\nshopt -s expand_aliases\nalias aws=\"docker run --rm -i -v $(pwd):/build -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli\"\n\necho \"##octopus[stdout-default]\"\n\nSTAGE_URL=$(aws cloudformation \\\n    describe-stacks \\\n    --stack-name \"OctopubApiGatewayStage-#{Octopus.Environment.Name | Replace \" .*\" \"\"}\" \\\n    --query \"Stacks[0].Outputs[?OutputKey=='StageURL'].OutputValue\" \\\n    --output text)\n\nset_octopusvariable \"StageURL\" $${STAGE_URL}\necho \"Stage URL: $STAGE_URL\"\n\nDNS_NAME=$(aws cloudformation \\\n    describe-stacks \\\n    --stack-name \"OctopubApiGatewayStage-#{Octopus.Environment.Name | Replace \" .*\" \"\"}\" \\\n    --query \"Stacks[0].Outputs[?OutputKey=='DnsName'].OutputValue\" \\\n    --output text)\n\nset_octopusvariable \"DNSName\" $${DNS_NAME}\necho \"DNS Name: $DNS_NAME\"\n\nwrite_highlight \"Open [$${STAGE_URL}index.html]($${STAGE_URL}index.html) to view the frontend web app.\"\n"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Script.ScriptSource" = "Inline"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
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
}