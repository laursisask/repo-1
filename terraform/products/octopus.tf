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

resource "octopusdeploy_project_group" "project_group_products" {
  name        = "Products API"
  description = "The products REST API"
}

resource "octopusdeploy_project" "project_products_service" {
  name                                 = "Products Service"
  auto_create_release                  = false
  default_guided_failure_mode          = "EnvironmentDefault"
  default_to_skip_if_already_installed = false
  description                          = "Deploys the backend service to Lambda."
  discrete_channel_release             = false
  is_disabled                          = false
  is_version_controlled                = false
  lifecycle_id                         = "${data.octopusdeploy_lifecycles.default.lifecycles[0].id}"
  project_group_id                     = "${octopusdeploy_project_group.project_group_products.id}"
  included_library_variable_sets       = ["${data.octopusdeploy_library_variable_sets.library_variable_set_octopub.library_variable_sets[0].id}"]
  tenanted_deployment_participation    = "Untenanted"

  connectivity_policy {
    allow_deployments_to_no_targets = false
    exclude_unhealthy_targets       = false
    skip_machine_behavior           = "SkipUnavailableMachines"
  }
}

resource "octopusdeploy_deployment_process" "deployment_process_project_products_service" {
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
        "Octopus.Action.Aws.CloudFormationTemplate" = "Resources:\n  LambdaS3Bucket:\n    Type: 'AWS::S3::Bucket'\nOutputs:\n  LambdaS3Bucket:\n    Description: The S3 Bucket\n    Value:\n      Ref: LambdaS3Bucket\n"
        "Octopus.Action.Aws.WaitForCompletion" = "True"
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubBackendS3Bucket-#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.Aws.TemplateSource" = "Inline"
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([])
        "Octopus.Action.Aws.CloudFormation.Tags" = jsonencode([
          {
            "key" = "OctopusTenantId"
            "value" = "#{if Octopus.Deployment.Tenant.Id}#{Octopus.Deployment.Tenant.Id}#{/if}#{unless Octopus.Deployment.Tenant.Id}untenanted#{/unless}"
          },
          {
            "key" = "OctopusStepId"
            "value" = "#{Octopus.Step.Id}"
          },
          {
            "key" = "OctopusRunbookRunId"
            "value" = "#{if Octopus.RunBookRun.Id}#{Octopus.RunBookRun.Id}#{/if}#{unless Octopus.RunBookRun.Id}none#{/unless}"
          },
          {
            "key" = "OctopusDeploymentId"
            "value" = "#{if Octopus.Deployment.Id}#{Octopus.Deployment.Id}#{/if}#{unless Octopus.Deployment.Id}none#{/unless}"
          },
          {
            "key" = "OctopusProjectId"
            "value" = "#{Octopus.Project.Id}"
          },
          {
            "key" = "OctopusEnvironmentId"
            "value" = "#{Octopus.Environment.Id}"
          },
          {
            "value" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
            "key" = "Environment"
          },
          {
            "value" = "#{Octopus.Project.Name | Replace \" \" \"_\"}"
            "key" = "DeploymentProject"
          },
        ])
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Aws.IamCapabilities" = jsonencode([
          "CAPABILITY_AUTO_EXPAND",
          "CAPABILITY_IAM",
          "CAPABILITY_NAMED_IAM",
        ])
        "Octopus.Action.Aws.CloudFormationTemplateParametersRaw" = jsonencode([])
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.AssumeRole" = "False"
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
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.Aws.S3.BucketName" = "#{Octopus.Action[Create S3 bucket].Output.AwsOutputs[LambdaS3Bucket]}"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.S3.TargetMode" = "EntirePackage"
        "Octopus.Action.Package.DownloadOnTentacle" = "False"
        "Octopus.Action.Aws.S3.PackageOptions" = jsonencode({
          "storageClass" = "STANDARD"
          "tags" = []
          "bucketKey" = ""
          "bucketKeyBehaviour" = "Filename"
          "bucketKeyPrefix" = ""
          "cannedAcl" = "private"
          "metadata" = []
        })
      }
      environments                       = []
      excluded_environments              = []
      channels                           = []
      tenant_tags                        = []

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
        "OctopusUseBundledTooling" = "False"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Script.ScriptBody" = "echo \"Downloading Docker images\"\n\necho \"##octopus[stdout-verbose]\"\n\ndocker pull amazon/aws-cli 2\u003e\u00261\n\n# Alias the docker run commands\nshopt -s expand_aliases\nalias aws=\"docker run --rm -i -v $(pwd):/build -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli\"\n\necho \"##octopus[stdout-default]\"\n\nAPI_RESOURCE=$(aws cloudformation \\\n    describe-stacks \\\n    --stack-name #{AWS.CloudFormation.ApiGatewayStack} \\\n    --query \"Stacks[0].Outputs[?OutputKey=='Api'].OutputValue\" \\\n    --output text)\n\nset_octopusvariable \"Api\" $${API_RESOURCE}\n\necho \"API Resource ID: $${API_RESOURCE}\"\n\nif [[ -z \"$${API_RESOURCE}\" ]]; then\n  echo \"Run the API Gateway project first\"\n  exit 1\nfi\n\nREST_API=$(aws cloudformation \\\n    describe-stacks \\\n    --stack-name #{AWS.CloudFormation.ApiGatewayStack} \\\n    --query \"Stacks[0].Outputs[?OutputKey=='RestApi'].OutputValue\" \\\n    --output text)\n\nset_octopusvariable \"RestApi\" $${REST_API}\n\necho \"Rest Api ID: $${REST_API}\"\n\nif [[ -z \"$${REST_API}\" ]]; then\n  echo \"Run the API Gateway project first\"\n  exit 1\nfi\n\n"
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.Script.ScriptSource" = "Inline"
        "Octopus.Action.Script.Syntax" = "Bash"
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
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.IamCapabilities" = jsonencode([
          "CAPABILITY_AUTO_EXPAND",
          "CAPABILITY_IAM",
          "CAPABILITY_NAMED_IAM",
        ])
        "Octopus.Action.Aws.TemplateSource" = "Inline"
        "Octopus.Action.Aws.CloudFormationTemplateParametersRaw" = jsonencode([])
        "Octopus.Action.Template.Version" = "1"
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubProductsLambda-#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
        "Vpc.Cidr" = "10.0.0.0/16"
        "Octopus.Action.Aws.CloudFormation.Tags" = jsonencode([
          {
            "key" = "OctopusTenantId"
            "value" = "#{if Octopus.Deployment.Tenant.Id}#{Octopus.Deployment.Tenant.Id}#{/if}#{unless Octopus.Deployment.Tenant.Id}untenanted#{/unless}"
          },
          {
            "key" = "OctopusStepId"
            "value" = "#{Octopus.Step.Id}"
          },
          {
            "key" = "OctopusRunbookRunId"
            "value" = "#{if Octopus.RunBookRun.Id}#{Octopus.RunBookRun.Id}#{/if}#{unless Octopus.RunBookRun.Id}none#{/unless}"
          },
          {
            "key" = "OctopusDeploymentId"
            "value" = "#{if Octopus.Deployment.Id}#{Octopus.Deployment.Id}#{/if}#{unless Octopus.Deployment.Id}none#{/unless}"
          },
          {
            "key" = "OctopusProjectId"
            "value" = "#{Octopus.Project.Id}"
          },
          {
            "key" = "OctopusEnvironmentId"
            "value" = "#{Octopus.Environment.Id}"
          },
          {
            "value" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
            "key" = "Environment"
          },
          {
            "value" = "#{Octopus.Project.Name | Replace \" \" \"_\"}"
            "key" = "DeploymentProject"
          },
        ])
        "Octopus.Action.Aws.CloudFormationTemplate" = "# This stack creates a new application lambda.\nParameters:\n  EnvironmentName:\n    Type: String\n    Default: '#{Octopus.Environment.Name}'\n  RestApi:\n    Type: String\n  ResourceId:\n    Type: String\n  LambdaS3Key:\n    Type: String\n  LambdaS3Bucket:\n    Type: String\n  LambdaName:\n    Type: String\n  SubnetGroupName:\n    Type: String\n  LambdaDescription:\n    Type: String\n  DBUsername:\n    Type: String\n  DBPassword:\n    Type: String\nResources:\n  VPC:\n    Type: \"AWS::EC2::VPC\"\n    Properties:\n      CidrBlock: \"#{Vpc.Cidr}\"\n      Tags:\n      - Key: \"Name\"\n        Value: !Ref LambdaName\n  SubnetA:\n    Type: \"AWS::EC2::Subnet\"\n    Properties:\n      AvailabilityZone: !Select\n        - 0\n        - !GetAZs\n          Ref: 'AWS::Region'\n      VpcId: !Ref \"VPC\"\n      CidrBlock: \"10.0.0.0/24\"\n  SubnetB:\n    Type: \"AWS::EC2::Subnet\"\n    Properties:\n      AvailabilityZone: !Select\n        - 1\n        - !GetAZs\n          Ref: 'AWS::Region'\n      VpcId: !Ref \"VPC\"\n      CidrBlock: \"10.0.1.0/24\"\n  RouteTable:\n    Type: \"AWS::EC2::RouteTable\"\n    Properties:\n      VpcId: !Ref \"VPC\"\n  SubnetGroup:\n    Type: \"AWS::RDS::DBSubnetGroup\"\n    Properties:\n      DBSubnetGroupName: !Ref SubnetGroupName\n      DBSubnetGroupDescription: \"Subnet Group\"\n      SubnetIds:\n      - !Ref \"SubnetA\"\n      - !Ref \"SubnetB\"\n  InstanceSecurityGroup:\n    Type: \"AWS::EC2::SecurityGroup\"\n    Properties:\n      GroupName: \"Example Security Group\"\n      GroupDescription: \"RDS traffic\"\n      VpcId: !Ref \"VPC\"\n      SecurityGroupEgress:\n      - IpProtocol: \"-1\"\n        CidrIp: \"0.0.0.0/0\"\n  InstanceSecurityGroupIngress:\n    Type: \"AWS::EC2::SecurityGroupIngress\"\n    DependsOn: \"InstanceSecurityGroup\"\n    Properties:\n      GroupId: !Ref \"InstanceSecurityGroup\"\n      IpProtocol: \"tcp\"\n      FromPort: \"0\"\n      ToPort: \"65535\"\n      SourceSecurityGroupId: !Ref \"InstanceSecurityGroup\"\n  RDSCluster:\n    Type: \"AWS::RDS::DBCluster\"\n    Properties:\n      DBSubnetGroupName: !Ref \"SubnetGroup\"\n      MasterUsername: !Ref \"DBUsername\"\n      MasterUserPassword: !Ref \"DBPassword\"\n      DatabaseName: \"products\"\n      Engine: \"aurora-mysql\"\n      EngineMode: \"serverless\"\n      VpcSecurityGroupIds:\n      - !Ref \"InstanceSecurityGroup\"\n      ScalingConfiguration:\n        AutoPause: true\n        MaxCapacity: 1\n        MinCapacity: 1\n        SecondsUntilAutoPause: 300\n    DependsOn:\n      - SubnetGroup\n  AppLogGroup:\n    Type: 'AWS::Logs::LogGroup'\n    Properties:\n      LogGroupName: !Sub '/aws/lambda/$${LambdaName}'\n      RetentionInDays: 14\n  IamRoleLambdaExecution:\n    Type: 'AWS::IAM::Role'\n    Properties:\n      AssumeRolePolicyDocument:\n        Version: 2012-10-17\n        Statement:\n          - Effect: Allow\n            Principal:\n              Service:\n                - lambda.amazonaws.com\n            Action:\n              - 'sts:AssumeRole'\n      Policies:\n        - PolicyName: !Sub '$${LambdaName}-policy'\n          PolicyDocument:\n            Version: 2012-10-17\n            Statement:\n              - Effect: Allow\n                Action:\n                  - 'logs:CreateLogStream'\n                  - 'logs:CreateLogGroup'\n                  - 'logs:PutLogEvents'\n                Resource:\n                  - !Sub \u003e-\n                    arn:$${AWS::Partition}:logs:$${AWS::Region}:$${AWS::AccountId}:log-group:/aws/lambda/$${LambdaName}*:*\n              - Effect: Allow\n                Action:\n                  - 'ec2:DescribeInstances'\n                  - 'ec2:CreateNetworkInterface'\n                  - 'ec2:AttachNetworkInterface'\n                  - 'ec2:DeleteNetworkInterface'\n                  - 'ec2:DescribeNetworkInterfaces'\n                Resource: \"*\"\n      Path: /\n      RoleName: !Sub '$${LambdaName}-role'\n  MigrationLambda:\n    Type: 'AWS::Lambda::Function'\n    Properties:\n      Description: !Ref LambdaDescription\n      Code:\n        S3Bucket: !Ref LambdaS3Bucket\n        S3Key: !Ref LambdaS3Key\n      Environment:\n        Variables:\n          DATABASE_HOSTNAME: !GetAtt\n          - RDSCluster\n          - Endpoint.Address\n          DATABASE_USERNAME: !Ref \"DBUsername\"\n          DATABASE_PASSWORD: !Ref \"DBPassword\"\n          MIGRATE_AT_START: !!str \"false\"\n          LAMBDA_NAME: \"DatabaseInit\"\n          QUARKUS_PROFILE: \"faas\"\n      FunctionName: !Sub '$${LambdaName}-DBMigration'\n      Handler: not.used.in.provided.runtime\n      MemorySize: 256\n      PackageType: Zip\n      Role: !GetAtt\n        - IamRoleLambdaExecution\n        - Arn\n      Runtime: provided\n      Timeout: 600\n      VpcConfig:\n        SecurityGroupIds:\n          - !Ref \"InstanceSecurityGroup\"\n        SubnetIds:\n          - !Ref \"SubnetA\"\n          - !Ref \"SubnetB\"\n  ApplicationLambda:\n    Type: 'AWS::Lambda::Function'\n    Properties:\n      Description: !Ref LambdaDescription\n      Code:\n        S3Bucket: !Ref LambdaS3Bucket\n        S3Key: !Ref LambdaS3Key\n      Environment:\n        Variables:\n          DATABASE_HOSTNAME: !GetAtt\n          - RDSCluster\n          - Endpoint.Address\n          DATABASE_USERNAME: !Ref \"DBUsername\"\n          DATABASE_PASSWORD: !Ref \"DBPassword\"\n          MIGRATE_AT_START: !!str \"false\"\n          QUARKUS_PROFILE: \"faas\"\n      FunctionName: !Sub '$${LambdaName}'\n      Handler: not.used.in.provided.runtime\n      MemorySize: 256\n      PackageType: Zip\n      Role: !GetAtt\n        - IamRoleLambdaExecution\n        - Arn\n      Runtime: provided\n      Timeout: 600\n      VpcConfig:\n        SecurityGroupIds:\n          - !Ref \"InstanceSecurityGroup\"\n        SubnetIds:\n          - !Ref \"SubnetA\"\n          - !Ref \"SubnetB\"\nOutputs:\n  ApplicationLambda:\n    Description: The Lambda ref\n    Value: !Ref ApplicationLambda\n"
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
            "ParameterKey" = "ResourceId"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.Api}"
          },
          {
            "ParameterKey" = "LambdaS3Key"
            "ParameterValue" = "#{Octopus.Action[Upload Lambda].Package[].PackageId}.#{Octopus.Action[Upload Lambda].Package[].PackageVersion}.zip"
          },
          {
            "ParameterKey" = "LambdaS3Bucket"
            "ParameterValue" = "#{Octopus.Action[Create S3 bucket].Output.AwsOutputs[LambdaS3Bucket]}"
          },
          {
            "ParameterKey" = "LambdaName"
            "ParameterValue" = "octopub-products-#{Octopus.Environment.Name | Replace \" .*\" \"\" | ToLower}"
          },
          {
            "ParameterKey" = "SubnetGroupName"
            "ParameterValue" = "octopub-products-#{Octopus.Environment.Name | Replace \" .*\" \"\" | ToLower}"
          },
          {
            "ParameterKey" = "LambdaDescription"
            "ParameterValue" = "#{Octopus.Deployment.Id} v#{Octopus.Action[Upload Lambda].Package[].PackageVersion}"
          },
          {
            "ParameterKey" = "DBUsername"
            "ParameterValue" = "productadmin"
          },
          {
            "ParameterKey" = "DBPassword"
            "ParameterValue" = "Password01!"
          },
        ])
        "Octopus.Action.Aws.AssumeRole" = "False"
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
        "OctopusUseBundledTooling" = "False"
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Script.ScriptBody" = "echo \"Downloading Docker images\"\n\necho \"##octopus[stdout-verbose]\"\n\ndocker pull amazon/aws-cli 2\u003e\u00261\n\n# Alias the docker run commands\nshopt -s expand_aliases\nalias aws=\"docker run --rm -i -v $(pwd):/build -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY amazon/aws-cli\"\n\necho \"##octopus[stdout-default]\"\n\naws lambda invoke \\\n  --function-name 'octopub-products-#{Octopus.Environment.Name | Replace \" .*\" \"\" | ToLower}-DBMigration' \\\n  --payload '{}' \\\n  response.json\n"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.Script.ScriptSource" = "Inline"
        "Octopus.Action.Script.Syntax" = "Bash"
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
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubProductsLambdaVersion-#{Octopus.Environment.Name | Replace \" .*\" \"\"}-#{Octopus.Deployment.Id | Replace -}"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Aws.CloudFormation.Tags" = jsonencode([
          {
            "key" = "OctopusTenantId"
            "value" = "#{if Octopus.Deployment.Tenant.Id}#{Octopus.Deployment.Tenant.Id}#{/if}#{unless Octopus.Deployment.Tenant.Id}untenanted#{/unless}"
          },
          {
            "key" = "OctopusStepId"
            "value" = "#{Octopus.Step.Id}"
          },
          {
            "key" = "OctopusRunbookRunId"
            "value" = "#{if Octopus.RunBookRun.Id}#{Octopus.RunBookRun.Id}#{/if}#{unless Octopus.RunBookRun.Id}none#{/unless}"
          },
          {
            "key" = "OctopusDeploymentId"
            "value" = "#{if Octopus.Deployment.Id}#{Octopus.Deployment.Id}#{/if}#{unless Octopus.Deployment.Id}none#{/unless}"
          },
          {
            "key" = "OctopusProjectId"
            "value" = "#{Octopus.Project.Id}"
          },
          {
            "key" = "OctopusEnvironmentId"
            "value" = "#{Octopus.Environment.Id}"
          },
          {
            "value" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
            "key" = "Environment"
          },
          {
            "value" = "#{Octopus.Project.Name | Replace \" \" \"_\"}"
            "key" = "DeploymentProject"
          },
        ])
        "Octopus.Action.Aws.WaitForCompletion" = "True"
        "Octopus.Action.Aws.TemplateSource" = "Inline"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.CloudFormationTemplate" = "# This template creates a new lambda version for the application lambda created in the\n# previous step. This template is created in a unique stack each time, and is cleaned\n# up by Octopus once the API gateway no longer points to this version.\nParameters:\n  RestApi:\n    Type: String\n  LambdaDescription:\n    Type: String\n  ApplicationLambda:\n    Type: String\nResources:\n  LambdaVersion:\n    Type: 'AWS::Lambda::Version'\n    Properties:\n      FunctionName: !Ref ApplicationLambda\n      Description: !Ref LambdaDescription\n  ApplicationLambdaPermissions:\n    Type: 'AWS::Lambda::Permission'\n    Properties:\n      FunctionName: !Ref LambdaVersion\n      Action: 'lambda:InvokeFunction'\n      Principal: apigateway.amazonaws.com\n      SourceArn: !Join\n        - ''\n        - - 'arn:'\n          - !Ref 'AWS::Partition'\n          - ':execute-api:'\n          - !Ref 'AWS::Region'\n          - ':'\n          - !Ref 'AWS::AccountId'\n          - ':'\n          - !Ref RestApi\n          - /*/*\nOutputs:\n  LambdaVersion:\n    Description: The name of the Lambda version resource deployed by this template\n    Value: !Ref LambdaVersion\n"
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([
          {
            "ParameterKey" = "RestApi"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RestApi}"
          },
          {
            "ParameterKey" = "LambdaDescription"
            "ParameterValue" = "#{Octopus.Deployment.Id} v#{Octopus.Action[Upload Lambda].Package[].PackageVersion}"
          },
          {
            "ParameterKey" = "ApplicationLambda"
            "ParameterValue" = "#{Octopus.Action[Deploy Application Lambda].Output.AwsOutputs[ApplicationLambda]}"
          },
        ])
        "Octopus.Action.Aws.CloudFormationTemplateParametersRaw" = jsonencode([
          {
            "ParameterKey" = "RestApi"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RestApi}"
          },
          {
            "ParameterKey" = "LambdaDescription"
            "ParameterValue" = "#{Octopus.Deployment.Id} v#{Octopus.Action[Upload Lambda].Package[].PackageVersion}"
          },
          {
            "ParameterKey" = "ApplicationLambda"
            "ParameterValue" = "#{Octopus.Action[Deploy Application Lambda].Output.AwsOutputs[ApplicationLambda]}"
          },
        ])
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
    name                = "Update API Gateway"
    package_requirement = "LetOctopusDecide"
    start_trigger       = "StartAfterPrevious"

    action {
      action_type                        = "Octopus.AwsRunCloudFormation"
      name                               = "Update API Gateway"
      notes                              = "This step attaches the reverse proxy version created in the previous step to the API Gateway, and creates an API Gateway deployment."
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
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
            "ParameterKey" = "ResourceId"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.Api}"
          },
          {
            "ParameterKey" = "ProxyLambdaVersion"
            "ParameterValue" = "#{Octopus.Action[Deploy Application Lambda Version].Output.AwsOutputs[LambdaVersion]}"
          },
        ])
        "Octopus.Action.Aws.CloudFormationTemplateParametersRaw" = jsonencode([])
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubProductsApiGateway-#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
        "Octopus.Action.Aws.CloudFormationTemplate" = "# This template links the reverse proxy to the API Gateway. Once this linking is done,\n# the API Gateway is ready to be deployed to a stage. But the old Lambda versions are\n# still referenced by the existing stage, so no changes have been exposed to the\n# end user.\nParameters:\n  EnvironmentName:\n    Type: String\n    Default: '#{Octopus.Environment.Name | Replace \" .*\" \"\"}'\n  RestApi:\n    Type: String\n  ResourceId:\n    Type: String\n  ProxyLambdaVersion:\n    Type: String\nResources:\n  ApiProductsResource:\n    Type: 'AWS::ApiGateway::Resource'\n    Properties:\n      RestApiId: !Ref RestApi\n      ParentId: !Ref ResourceId\n      PathPart: products\n  ApiProductsProxyResource:\n    Type: 'AWS::ApiGateway::Resource'\n    Properties:\n      RestApiId: !Ref RestApi\n      ParentId: !Ref ApiProductsResource\n      PathPart: '{proxy+}'\n  ApiProductsMethod:\n    Type: 'AWS::ApiGateway::Method'\n    Properties:\n      AuthorizationType: NONE\n      HttpMethod: ANY\n      Integration:\n        IntegrationHttpMethod: POST\n        TimeoutInMillis: 20000\n        Type: AWS_PROXY\n        Uri: !Join\n          - ''\n          - - 'arn:'\n            - !Ref 'AWS::Partition'\n            - ':apigateway:'\n            - !Ref 'AWS::Region'\n            - ':lambda:path/2015-03-31/functions/'\n            - !Ref ProxyLambdaVersion\n            - /invocations\n      ResourceId: !Ref ApiProductsResource\n      RestApiId: !Ref RestApi\n  ApiProxyProductsMethod:\n    Type: 'AWS::ApiGateway::Method'\n    Properties:\n      AuthorizationType: NONE\n      HttpMethod: ANY\n      Integration:\n        IntegrationHttpMethod: POST\n        TimeoutInMillis: 20000\n        Type: AWS_PROXY\n        Uri: !Join\n          - ''\n          - - 'arn:'\n            - !Ref 'AWS::Partition'\n            - ':apigateway:'\n            - !Ref 'AWS::Region'\n            - ':lambda:path/2015-03-31/functions/'\n            - !Ref ProxyLambdaVersion\n            - /invocations\n      ResourceId: !Ref ApiProductsProxyResource\n      RestApiId: !Ref RestApi\n  'Deployment#{Octopus.Deployment.Id | Replace -}':\n    Type: 'AWS::ApiGateway::Deployment'\n    Properties:\n      RestApiId: !Ref RestApi\n    DependsOn:\n      - ApiProductsMethod\nOutputs:\n  DeploymentId:\n    Description: The deployment id\n    Value: !Ref 'Deployment#{Octopus.Deployment.Id | Replace -}'\n  ApiProductsMethod:\n    Description: The method hosting the root api endpoint\n    Value: !Ref ApiProductsMethod\n  ApiProxyProductsMethod:\n    Description: The method hosting the api endpoint subdirectories\n    Value: !Ref ApiProxyProductsMethod\n  DownstreamService:\n    Description: The function that was configured to accept traffic.\n    Value: !Join\n      - ''\n      - - 'arn:'\n        - !Ref 'AWS::Partition'\n        - ':apigateway:'\n        - !Ref 'AWS::Region'\n        - ':lambda:path/2015-03-31/functions/'\n        - !Ref ProxyLambdaVersion\n        - /invocations\n"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.Aws.WaitForCompletion" = "True"
        "Octopus.Action.Aws.TemplateSource" = "Inline"
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
        "Octopus.Action.Aws.IamCapabilities" = jsonencode([
          "CAPABILITY_AUTO_EXPAND",
          "CAPABILITY_IAM",
          "CAPABILITY_NAMED_IAM",
        ])
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.CloudFormation.Tags" = jsonencode([
          {
            "key" = "OctopusTenantId"
            "value" = "#{if Octopus.Deployment.Tenant.Id}#{Octopus.Deployment.Tenant.Id}#{/if}#{unless Octopus.Deployment.Tenant.Id}untenanted#{/unless}"
          },
          {
            "key" = "OctopusStepId"
            "value" = "#{Octopus.Step.Id}"
          },
          {
            "key" = "OctopusRunbookRunId"
            "value" = "#{if Octopus.RunBookRun.Id}#{Octopus.RunBookRun.Id}#{/if}#{unless Octopus.RunBookRun.Id}none#{/unless}"
          },
          {
            "key" = "OctopusDeploymentId"
            "value" = "#{if Octopus.Deployment.Id}#{Octopus.Deployment.Id}#{/if}#{unless Octopus.Deployment.Id}none#{/unless}"
          },
          {
            "key" = "OctopusProjectId"
            "value" = "#{Octopus.Project.Id}"
          },
          {
            "key" = "OctopusEnvironmentId"
            "value" = "#{Octopus.Environment.Id}"
          },
          {
            "value" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
            "key" = "Environment"
          },
          {
            "value" = "#{Octopus.Project.Name | Replace \" \" \"_\"}"
            "key" = "DeploymentProject"
          },
        ])
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
      notes                              = "This step deploys the deployment created in the previous step, effectively exposing the new Lambdas to the public."
      condition                          = "Success"
      run_on_server                      = true
      is_disabled                        = false
      can_be_used_for_project_versioning = false
      is_required                        = false
      worker_pool_id                     = "${data.octopusdeploy_worker_pools.workerpool_hosted_ubuntu.worker_pools[0].id}"
      properties                         = {
        "Octopus.Action.Aws.WaitForCompletion" = "True"
        "Octopus.Action.Aws.CloudFormation.Tags" = jsonencode([
          {
            "key" = "Environment"
            "value" = "#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
          },
          {
            "key" = "DeploymentProject"
            "value" = "Backend_Service"
          },
        ])
        "Octopus.Action.Aws.CloudFormationTemplate" = "# This template updates the stage with the deployment created in the previous step.\n# It is here that the new Lambda versions are exposed to the end user.\nParameters:\n  EnvironmentName:\n    Type: String\n    Default: '#{Octopus.Environment.Name | Replace \" .*\" \"\"}'\n  DeploymentId:\n    Type: String\n    Default: 'Deployment#{DeploymentId}'\n  ApiGatewayId:\n    Type: String\nResources:\n  Stage:\n    Type: 'AWS::ApiGateway::Stage'\n    Properties:\n      DeploymentId:\n        'Fn::Sub': '$${DeploymentId}'\n      RestApiId:\n        'Fn::Sub': '$${ApiGatewayId}'\n      StageName:\n        'Fn::Sub': '$${EnvironmentName}'\nOutputs:\n  DnsName:\n    Value:\n      'Fn::Join':\n        - ''\n        - - Ref: ApiGatewayId\n          - .execute-api.\n          - Ref: 'AWS::Region'\n          - .amazonaws.com\n  StageURL:\n    Description: The url of the stage\n    Value:\n      'Fn::Join':\n        - ''\n        - - 'https://'\n          - Ref: ApiGatewayId\n          - .execute-api.\n          - Ref: 'AWS::Region'\n          - .amazonaws.com/\n          - Ref: Stage\n          - /\n"
        "Octopus.Action.Aws.TemplateSource" = "Inline"
        "Octopus.Action.Aws.CloudFormationStackName" = "OctopubApiGatewayStage-#{Octopus.Environment.Name | Replace \" .*\" \"\"}"
        "Octopus.Action.AwsAccount.UseInstanceRole" = "False"
        "Octopus.Action.Aws.CloudFormationTemplateParameters" = jsonencode([
          {
            "ParameterKey" = "EnvironmentName"
            "ParameterValue" = "#{Octopus.Environment.Name | Replace \" .*\" \"\" }"
          },
          {
            "ParameterKey" = "DeploymentId"
            "ParameterValue" = "#{Octopus.Action[Update API Gateway].Output.AwsOutputs[DeploymentId]}"
          },
          {
            "ParameterKey" = "ApiGatewayId"
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RestApi}"
          },
        ])
        "Octopus.Action.Aws.Region" = "#{AWS.Region}"
        "Octopus.Action.Aws.AssumeRole" = "False"
        "Octopus.Action.Aws.CloudFormationTemplateParametersRaw" = jsonencode([
          {
            "ParameterKey" = "EnvironmentName"
            "ParameterValue" = "#{Octopus.Environment.Name | Replace \" .*\" \"\" }"
          },
          {
            "ParameterValue" = "#{Octopus.Action[Update API Gateway].Output.AwsOutputs[DeploymentId]}"
            "ParameterKey" = "DeploymentId"
          },
          {
            "ParameterValue" = "#{Octopus.Action[Get Stack Outputs].Output.RestApi}"
            "ParameterKey" = "ApiGatewayId"
          },
        ])
        "Octopus.Action.AwsAccount.Variable" = "AWS.Account"
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