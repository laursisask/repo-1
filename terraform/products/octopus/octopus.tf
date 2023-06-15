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

data "octopusdeploy_feeds" "sales_maven_feed" {
  feed_type    = "Maven"
  ids          = []
  partial_name = "Sales Maven Feed"
  skip         = 0
  take         = 1
}

resource "octopusdeploy_project_group" "project_group_products" {
  name        = "Products API"
  description = "The products REST API"
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

resource "octopusdeploy_project" "project_products_service" {
  name                                 = "Products Service"
  auto_create_release                  = false
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = "Deploys the backend service to Lambda."
  discrete_channel_release             = false
  is_disabled                          = false
  lifecycle_id                         = "${data.octopusdeploy_lifecycles.default.lifecycles[0].id}"
  project_group_id                     = length(var.existing_project_group) == 0 ? octopusdeploy_project_group.project_group_products[0].id : data.octopusdeploy_project_groups.existing_project_group.project_groups[0].id
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

resource "octopusdeploy_deployment_process" "deployment_process_project_products_service" {
  # Ignoring the step field allows Terraform to create the project and steps, but
  # then ignore any changes made via the UI. This is useful when Terraform is used
  # to bootstrap the project but not "own" the configuration once it exists.

  # lifecycle {
  #   ignore_changes = [
  #     step,
  #   ]
  # }

  project_id = "${octopusdeploy_project.project_products_service.id}"

  step {
    condition           = "Success"
    name                = "Create S3 bucket"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunCloudFormation"
      name                               = "Create S3 bucket"
      notes                              = "Create an S3 bucket to hold the Lambda application code that is to be deployed."
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Aws.CloudFormationTemplate"           = "Resources:\n  LambdaS3Bucket:\n    Type: 'AWS::S3::Bucket'\nOutputs:\n  LambdaS3Bucket:\n    Description: The S3 Bucket\n    Value:\n      Ref: LambdaS3Bucket\n"
        "Octopus.Action.Aws.WaitForCompletion"                = "True"
        "Octopus.Action.Aws.CloudFormationStackName"          = "OctopubBackendS3Bucket-#{Octopus.Environment.Name}"
        "Octopus.Action.AwsAccount.UseInstanceRole"           = "False"
        "Octopus.Action.Aws.TemplateSource"                   = "Inline"
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([])
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
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Aws.IamCapabilities" = jsonencode([
          "CAPABILITY_AUTO_EXPAND",
          "CAPABILITY_IAM",
          "CAPABILITY_NAMED_IAM",
        ])
        "Octopus.Action.Aws.Region"     = "#{AWS.Region}"
        "Octopus.Action.Aws.AssumeRole" = "False"
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
    name                = "Upload Lambda"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsUploadS3"
      name                               = "Upload Lambda"
      notes                              = "Upload the Lambda application packages to the S3 bucket created in the previous step."
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = true
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Aws.AssumeRole"             = "False"
        "Octopus.Action.Aws.S3.BucketName"          = "#{Octopus.Action[Create S3 bucket].Output.AwsOutputs[LambdaS3Bucket]}"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.AwsAccount.Variable"        = "AWS.Account"
        "Octopus.Action.Aws.Region"                 = "#{AWS.Region}"
        "Octopus.Action.Aws.S3.TargetMode"          = "EntirePackage"
        "Octopus.Action.Package.DownloadOnTentacle" = "False"
        "Octopus.Action.Aws.S3.PackageOptions"      = jsonencode({
          "storageClass"       = "STANDARD"
          "tags"               = []
          "bucketKey"          = ""
          "bucketKeyBehaviour" = "Filename"
          "bucketKeyPrefix"    = ""
          "cannedAcl"          = "private"
          "metadata"           = []
        })
      }
      environments          = []
      excluded_environments = []
      channels              = []
      tenant_tags           = []

      primary_package {
        package_id           = "com.octopus:products-microservice-lambda"
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
    name                = "Get Stack Outputs"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunScript"
      name                               = "Get Stack Outputs"
      notes                              = "Read the CloudFormation outputs from the stack that created the shared API Gateway instance."
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "OctopusUseBundledTooling"                  = "False"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.AwsAccount.Variable"        = "AWS.Account"
        "Octopus.Action.Script.ScriptBody"          = <<-EOF
        echo "Downloading Docker images"

        echo "##octopus[stdout-verbose]"

        docker pull amazon/aws-cli 2>&1

        # Alias the docker run commands
        shopt -s expand_aliases
        alias aws="docker run --rm -i -v $(pwd):/build -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli"

        echo "##octopus[stdout-default]"

        API_RESOURCE=$(aws cloudformation \
            describe-stacks \
            --stack-name #{AWS.CloudFormation.ApiGatewayStack} \
            --query "Stacks[0].Outputs[?OutputKey=='Api'].OutputValue" \
            --output text)

        set_octopusvariable "Api" $${API_RESOURCE}

        echo "API Resource ID: $${API_RESOURCE}"

        if [[ -z "$${API_RESOURCE}" ]]; then
          echo "Run the API Gateway project first"
          exit 1
        fi

        REST_API=$(aws cloudformation \
            describe-stacks \
            --stack-name #{AWS.CloudFormation.ApiGatewayStack} \
            --query "Stacks[0].Outputs[?OutputKey=='RestApi'].OutputValue" \
            --output text)

        set_octopusvariable "RestApi" $${REST_API}

        echo "Rest Api ID: $${REST_API}"

        if [[ -z "$${REST_API}" ]]; then
          echo "Run the API Gateway project first"
          exit 1
        fi
        EOF
        "Octopus.Action.Aws.Region"                 = "#{AWS.Region}"
        "Octopus.Action.Aws.AssumeRole"             = "False"
        "Octopus.Action.Script.ScriptSource"        = "Inline"
        "Octopus.Action.Script.Syntax"              = "Bash"
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
    name                = "Deploy Application Lambda"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunCloudFormation"
      name                               = "Deploy Application Lambda"
      notes                              = "To achieve zero downtime deployments, we must deploy Lambdas and their versions in separate stacks. This stack deploys the main application Lambda."
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.AwsAccount.Variable"        = "AWS.Account"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.Aws.Region"                 = "#{AWS.Region}"
        "Octopus.Action.Aws.IamCapabilities"        = jsonencode([
          "CAPABILITY_AUTO_EXPAND",
          "CAPABILITY_IAM",
          "CAPABILITY_NAMED_IAM",
        ])
        "Octopus.Action.Aws.TemplateSource"          = "Inline"
        "Octopus.Action.Template.Version"            = "1"
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubProductsLambda-#{Octopus.Environment.Name}"
        "Vpc.Cidr"                                   = "10.0.0.0/16"
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
        "Octopus.Action.Aws.CloudFormationTemplate"           = <<-EOF
        # This stack creates a new application lambda.
        Parameters:
          EnvironmentName:
            Type: String
            Default: '#{Octopus.Environment.Name}'
          RestApi:
            Type: String
          ResourceId:
            Type: String
          LambdaS3Key:
            Type: String
          LambdaS3Bucket:
            Type: String
          LambdaName:
            Type: String
          SubnetGroupName:
            Type: String
          LambdaDescription:
            Type: String
          DBUsername:
            Type: String
          DBPassword:
            Type: String
        Resources:
          VPC:
            Type: "AWS::EC2::VPC"
            Properties:
              CidrBlock: "#{Vpc.Cidr}"
              Tags:
              - Key: "Name"
                Value: !Ref LambdaName
          SubnetA:
            Type: "AWS::EC2::Subnet"
            Properties:
              AvailabilityZone: !Select
                - 0
                - !GetAZs
                  Ref: 'AWS::Region'
              VpcId: !Ref "VPC"
              CidrBlock: "10.0.0.0/24"
          SubnetB:
            Type: "AWS::EC2::Subnet"
            Properties:
              AvailabilityZone: !Select
                - 1
                - !GetAZs
                  Ref: 'AWS::Region'
              VpcId: !Ref "VPC"
              CidrBlock: "10.0.1.0/24"
          RouteTable:
            Type: "AWS::EC2::RouteTable"
            Properties:
              VpcId: !Ref "VPC"
          SubnetGroup:
            Type: "AWS::RDS::DBSubnetGroup"
            Properties:
              DBSubnetGroupName: !Ref SubnetGroupName
              DBSubnetGroupDescription: "Subnet Group"
              SubnetIds:
              - !Ref "SubnetA"
              - !Ref "SubnetB"
          InstanceSecurityGroup:
            Type: "AWS::EC2::SecurityGroup"
            Properties:
              GroupName: "Example Security Group"
              GroupDescription: "RDS traffic"
              VpcId: !Ref "VPC"
              SecurityGroupEgress:
              - IpProtocol: "-1"
                CidrIp: "0.0.0.0/0"
          InstanceSecurityGroupIngress:
            Type: "AWS::EC2::SecurityGroupIngress"
            DependsOn: "InstanceSecurityGroup"
            Properties:
              GroupId: !Ref "InstanceSecurityGroup"
              IpProtocol: "tcp"
              FromPort: "0"
              ToPort: "65535"
              SourceSecurityGroupId: !Ref "InstanceSecurityGroup"
          RDSCluster:
            Type: "AWS::RDS::DBCluster"
            Properties:
              DBSubnetGroupName: !Ref "SubnetGroup"
              MasterUsername: !Ref "DBUsername"
              MasterUserPassword: !Ref "DBPassword"
              DatabaseName: "products"
              Engine: "aurora-mysql"
              EngineMode: "serverless"
              VpcSecurityGroupIds:
              - !Ref "InstanceSecurityGroup"
              ScalingConfiguration:
                AutoPause: true
                MaxCapacity: 1
                MinCapacity: 1
                SecondsUntilAutoPause: 300
            DependsOn:
              - SubnetGroup
          AppLogGroup:
            Type: 'AWS::Logs::LogGroup'
            Properties:
              LogGroupName: !Sub '/aws/lambda/$${LambdaName}'
              RetentionInDays: 14
          IamRoleLambdaExecution:
            Type: 'AWS::IAM::Role'
            Properties:
              AssumeRolePolicyDocument:
                Version: 2012-10-17
                Statement:
                  - Effect: Allow
                    Principal:
                      Service:
                        - lambda.amazonaws.com
                    Action:
                      - 'sts:AssumeRole'
              Policies:
                - PolicyName: !Sub '$${LambdaName}-policy'
                  PolicyDocument:
                    Version: 2012-10-17
                    Statement:
                      - Effect: Allow
                        Action:
                          - 'logs:CreateLogStream'
                          - 'logs:CreateLogGroup'
                          - 'logs:PutLogEvents'
                        Resource:
                          - !Sub >-
                            arn:$${AWS::Partition}:logs:$${AWS::Region}:$${AWS::AccountId}:log-group:/aws/lambda/$${LambdaName}*:*
                      - Effect: Allow
                        Action:
                          - 'ec2:DescribeInstances'
                          - 'ec2:CreateNetworkInterface'
                          - 'ec2:AttachNetworkInterface'
                          - 'ec2:DeleteNetworkInterface'
                          - 'ec2:DescribeNetworkInterfaces'
                        Resource: "*"
              Path: /
              RoleName: !Sub '$${LambdaName}-role'
          MigrationLambda:
            Type: 'AWS::Lambda::Function'
            Properties:
              Description: !Ref LambdaDescription
              Code:
                S3Bucket: !Ref LambdaS3Bucket
                S3Key: !Ref LambdaS3Key
              Environment:
                Variables:
                  DATABASE_HOSTNAME: !GetAtt
                  - RDSCluster
                  - Endpoint.Address
                  DATABASE_USERNAME: !Ref "DBUsername"
                  DATABASE_PASSWORD: !Ref "DBPassword"
                  MIGRATE_AT_START: !!str "false"
                  LAMBDA_NAME: "DatabaseInit"
                  QUARKUS_PROFILE: "faas"
              FunctionName: !Sub '$${LambdaName}-DBMigration'
              Handler: not.used.in.provided.runtime
              MemorySize: 256
              PackageType: Zip
              Role: !GetAtt
                - IamRoleLambdaExecution
                - Arn
              Runtime: provided
              Timeout: 600
              VpcConfig:
                SecurityGroupIds:
                  - !Ref "InstanceSecurityGroup"
                SubnetIds:
                  - !Ref "SubnetA"
                  - !Ref "SubnetB"
          ApplicationLambda:
            Type: 'AWS::Lambda::Function'
            Properties:
              Description: !Ref LambdaDescription
              Code:
                S3Bucket: !Ref LambdaS3Bucket
                S3Key: !Ref LambdaS3Key
              Environment:
                Variables:
                  DATABASE_HOSTNAME: !GetAtt
                  - RDSCluster
                  - Endpoint.Address
                  DATABASE_USERNAME: !Ref "DBUsername"
                  DATABASE_PASSWORD: !Ref "DBPassword"
                  MIGRATE_AT_START: !!str "false"
                  QUARKUS_PROFILE: "faas"
              FunctionName: !Sub '$${LambdaName}'
              Handler: not.used.in.provided.runtime
              MemorySize: 256
              PackageType: Zip
              Role: !GetAtt
                - IamRoleLambdaExecution
                - Arn
              Runtime: provided
              Timeout: 600
              VpcConfig:
                SecurityGroupIds:
                  - !Ref "InstanceSecurityGroup"
                SubnetIds:
                  - !Ref "SubnetA"
                  - !Ref "SubnetB"
        Outputs:
          ApplicationLambda:
            Description: The Lambda ref
            Value: !Ref ApplicationLambda
        EOF
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
            "ParameterKey"   = "ResourceId"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.Api}"
          },
          {
            "ParameterKey"   = "LambdaS3Key"
            "ParameterValue" = "#{Octopus.Action[Upload Lambda].Package[].PackageId}.#{Octopus.Action[Upload Lambda].Package[].PackageVersion}.zip"
          },
          {
            "ParameterKey"   = "LambdaS3Bucket"
            "ParameterValue" = "#{Octopus.Action[Create S3 bucket].Output.AwsOutputs[LambdaS3Bucket]}"
          },
          {
            "ParameterKey"   = "LambdaName"
            "ParameterValue" = "octopub-products-#{Octopus.Environment.Name | ToLower}"
          },
          {
            "ParameterKey"   = "SubnetGroupName"
            "ParameterValue" = "octopub-products-#{Octopus.Environment.Name | ToLower}"
          },
          {
            "ParameterKey"   = "LambdaDescription"
            "ParameterValue" = "#{Octopus.Deployment.Id} v#{Octopus.Action[Upload Lambda].Package[].PackageVersion}"
          },
          {
            "ParameterKey"   = "DBUsername"
            "ParameterValue" = "productadmin"
          },
          {
            "ParameterKey"   = "DBPassword"
            "ParameterValue" = "Password01!"
          },
        ])
        "Octopus.Action.Aws.AssumeRole"        = "False"
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
    name                = "Run Database Migrations"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunScript"
      name                               = "Run Database Migrations"
      notes                              = "Run the Lambda that performs database migrations."
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "OctopusUseBundledTooling"           = "False"
        "Octopus.Action.Aws.Region"          = "#{AWS.Region}"
        "Octopus.Action.Aws.AssumeRole"      = "False"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Script.ScriptBody"   = <<-EOF
        echo "Downloading Docker images"

        echo "##octopus[stdout-verbose]"

        docker pull amazon/aws-cli 2>&1

        # Alias the docker run commands
        shopt -s expand_aliases
        alias aws="docker run --rm -i -v $(pwd):/build -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli"

        echo "##octopus[stdout-default]"

        aws lambda invoke \
          --function-name 'octopub-products-#{Octopus.Environment.Name | Replace " .*" "" | ToLower}-DBMigration' \
          --payload '{}' \
          response.json
        EOF
        "Octopus.Action.Script.ScriptSource" = "Inline"
        "Octopus.Action.Script.Syntax"       = "Bash"
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
    name                = "Deploy Application Lambda Version"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunCloudFormation"
      name                               = "Deploy Application Lambda Version"
      notes                              = "Stacks deploying Lambda versions must have unique names to ensure a new version is created each time. This step deploys a uniquely names stack creating a version of the Lambda deployed in the last step."
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Aws.IamCapabilities" = jsonencode([
          "CAPABILITY_AUTO_EXPAND",
          "CAPABILITY_IAM",
          "CAPABILITY_NAMED_IAM",
        ])
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubProductsLambdaVersion-#{Octopus.Environment.Name}-#{Octopus.Deployment.Id | Replace -}"
        "Octopus.Action.Aws.AssumeRole"              = "False"
        "Octopus.Action.AwsAccount.Variable"         = "AWS.Account"
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
        "Octopus.Action.Aws.WaitForCompletion"                = "True"
        "Octopus.Action.Aws.TemplateSource"                   = "Inline"
        "Octopus.Action.AwsAccount.UseInstanceRole"           = "False"
        "Octopus.Action.Aws.Region"                           = "#{AWS.Region}"
        "Octopus.Action.Aws.CloudFormationTemplate"           = <<-EOF
        # This template creates a new lambda version for the application lambda created in the
        # previous step. This template is created in a unique stack each time, and is cleaned
        # up by Octopus once the API gateway no longer points to this version.
        Parameters:
          RestApi:
            Type: String
          LambdaDescription:
            Type: String
          ApplicationLambda:
            Type: String
        Resources:
          LambdaVersion:
            Type: 'AWS::Lambda::Version'
            Properties:
              FunctionName: !Ref ApplicationLambda
              Description: !Ref LambdaDescription
          ApplicationLambdaPermissions:
            Type: 'AWS::Lambda::Permission'
            Properties:
              FunctionName: !Ref LambdaVersion
              Action: 'lambda:InvokeFunction'
              Principal: apigateway.amazonaws.com
              SourceArn: !Join
                - ''
                - - 'arn:'
                  - !Ref 'AWS::Partition'
                  - ':execute-api:'
                  - !Ref 'AWS::Region'
                  - ':'
                  - !Ref 'AWS::AccountId'
                  - ':'
                  - !Ref RestApi
                  - /*/*
        Outputs:
          LambdaVersion:
            Description: The name of the Lambda version resource deployed by this template
            Value: !Ref LambdaVersion
        EOF
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([
          {
            "ParameterKey"   = "RestApi"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RestApi}"
          },
          {
            "ParameterKey"   = "LambdaDescription"
            "ParameterValue" = "#{Octopus.Deployment.Id} v#{Octopus.Action[Upload Lambda].Package[].PackageVersion}"
          },
          {
            "ParameterKey"   = "ApplicationLambda"
            "ParameterValue" = "#{Octopus.Action[Deploy Application Lambda].Output.AwsOutputs[ApplicationLambda]}"
          },
        ])
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
    name                = "Update API Gateway"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunCloudFormation"
      name                               = "Update API Gateway"
      notes                              = "Attach the Lambda to the API Gateway."
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
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
            "ParameterKey"   = "ResourceId"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.Api}"
          },
          {
            "ParameterKey"   = "LambdaVersion"
            "ParameterValue" = "#{Octopus.Action[Deploy Application Lambda Version].Output.AwsOutputs[LambdaVersion]}"
          },
        ])
        "Octopus.Action.AwsAccount.UseInstanceRole"  = "False"
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubProductsApiGateway-#{Octopus.Environment.Name}"
        "Octopus.Action.Aws.CloudFormationTemplate"  = <<-EOF
        Parameters:
          EnvironmentName:
            Type: String
            Default: '#{Octopus.Environment.Name | Replace " .*" ""}'
          RestApi:
            Type: String
          ResourceId:
            Type: String
          LambdaVersion:
            Type: String
        Resources:
          ApiProductsResource:
            Type: 'AWS::ApiGateway::Resource'
            Properties:
              RestApiId: !Ref RestApi
              ParentId: !Ref ResourceId
              PathPart: products
          ApiProductsProxyResource:
            Type: 'AWS::ApiGateway::Resource'
            Properties:
              RestApiId: !Ref RestApi
              ParentId: !Ref ApiProductsResource
              PathPart: '{proxy+}'
          ApiProductsMethod:
            Type: 'AWS::ApiGateway::Method'
            Properties:
              AuthorizationType: NONE
              HttpMethod: ANY
              Integration:
                IntegrationHttpMethod: POST
                TimeoutInMillis: 20000
                Type: AWS_PROXY
                Uri: !Join
                  - ''
                  - - 'arn:'
                    - !Ref 'AWS::Partition'
                    - ':apigateway:'
                    - !Ref 'AWS::Region'
                    - ':lambda:path/2015-03-31/functions/'
                    - !Ref LambdaVersion
                    - /invocations
              ResourceId: !Ref ApiProductsResource
              RestApiId: !Ref RestApi
          ApiProxyProductsMethod:
            Type: 'AWS::ApiGateway::Method'
            Properties:
              AuthorizationType: NONE
              HttpMethod: ANY
              Integration:
                IntegrationHttpMethod: POST
                TimeoutInMillis: 20000
                Type: AWS_PROXY
                Uri: !Join
                  - ''
                  - - 'arn:'
                    - !Ref 'AWS::Partition'
                    - ':apigateway:'
                    - !Ref 'AWS::Region'
                    - ':lambda:path/2015-03-31/functions/'
                    - !Ref LambdaVersion
                    - /invocations
              ResourceId: !Ref ApiProductsProxyResource
              RestApiId: !Ref RestApi
          'Deployment#{Octopus.Deployment.Id | Replace -}':
            Type: 'AWS::ApiGateway::Deployment'
            Properties:
              RestApiId: !Ref RestApi
            DependsOn:
              - ApiProductsMethod
              - ApiProxyProductsMethod
        Outputs:
          DeploymentId:
            Description: The deployment id
            Value: !Ref 'Deployment#{Octopus.Deployment.Id | Replace -}'
          ApiProductsMethod:
            Description: The method hosting the root api endpoint
            Value: !Ref ApiProductsMethod
          ApiProxyProductsMethod:
            Description: The method hosting the api endpoint subdirectories
            Value: !Ref ApiProxyProductsMethod
          DownstreamService:
            Description: The function that was configured to accept traffic.
            Value: !Join
              - ''
              - - 'arn:'
                - !Ref 'AWS::Partition'
                - ':apigateway:'
                - !Ref 'AWS::Region'
                - ':lambda:path/2015-03-31/functions/'
                - !Ref LambdaVersion
                - /invocations
        EOF
        "Octopus.Action.Aws.AssumeRole"              = "False"
        "Octopus.Action.Aws.WaitForCompletion"       = "True"
        "Octopus.Action.Aws.TemplateSource"          = "Inline"
        "Octopus.Action.AwsAccount.Variable"         = "AWS.Account"
        "Octopus.Action.Aws.IamCapabilities"         = jsonencode([
          "CAPABILITY_AUTO_EXPAND",
          "CAPABILITY_IAM",
          "CAPABILITY_NAMED_IAM",
        ])
        "Octopus.Action.Aws.Region"              = "#{AWS.Region}"
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
      notes                              = "This step deploys the deployment created in the previous step, effectively exposing the new Lambdas to the public."
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Aws.WaitForCompletion"   = "True"
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
        "Octopus.Action.Aws.CloudFormationTemplate"           = <<-EOF
        # This template updates the stage with the deployment created in the previous step.
        # It is here that the new Lambda versions are exposed to the end user.
        Parameters:
          EnvironmentName:
            Type: String
            Default: '#{Octopus.Environment.Name | Replace " .*" ""}'
          DeploymentId:
            Type: String
            Default: 'Deployment#{DeploymentId}'
          ApiGatewayId:
            Type: String
        Resources:
          Stage:
            Type: 'AWS::ApiGateway::Stage'
            Properties:
              DeploymentId:
                'Fn::Sub': '$${DeploymentId}'
              RestApiId:
                'Fn::Sub': '$${ApiGatewayId}'
              StageName:
                'Fn::Sub': '$${EnvironmentName}'
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
            Value:
              'Fn::Join':
                - ''
                - - 'https://'
                  - Ref: ApiGatewayId
                  - .execute-api.
                  - Ref: 'AWS::Region'
                  - .amazonaws.com/
                  - Ref: Stage
                  - /
        EOF
        "Octopus.Action.Aws.TemplateSource"                   = "Inline"
        "Octopus.Action.Aws.CloudFormationStackName"          = "OctopubApiGatewayStage-#{Octopus.Environment.Name}"
        "Octopus.Action.AwsAccount.UseInstanceRole"           = "False"
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([
          {
            "ParameterKey"   = "EnvironmentName"
            "ParameterValue" = "#{Octopus.Environment.Name }"
          },
          {
            "ParameterKey"   = "DeploymentId"
            "ParameterValue" = "#{Octopus.Action[Update API Gateway].Output.AwsOutputs[DeploymentId]}"
          },
          {
            "ParameterKey"   = "ApiGatewayId"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RestApi}"
          },
        ])
        "Octopus.Action.Aws.Region"          = "#{AWS.Region}"
        "Octopus.Action.Aws.AssumeRole"      = "False"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
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