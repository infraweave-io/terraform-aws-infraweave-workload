locals {
  is_workload_in_central = var.central_account_id == data.aws_caller_identity.current.account_id

  dynamodb_table_names = {
    events         = "Events-${var.central_account_id}-${var.region}-${var.environment}",
    modules        = "Modules-${var.central_account_id}-${var.region}-${var.environment}",
    policies       = "Policies-${var.central_account_id}-${var.region}-${var.environment}",
    change_records = "ChangeRecords-${var.central_account_id}-${var.region}-${var.environment}",
    deployments    = "Deployments-${var.central_account_id}-${var.region}-${var.environment}",
    tf_locks       = "TerraformStateDynamoDBLocks-${var.region}-${var.environment}",
  }

  bucket_names = {
    modules        = "tf-modules-${var.central_account_id}-${var.region}-${var.environment}",
    policies       = "tf-policies-${var.central_account_id}-${var.region}-${var.environment}",
    change_records = "tf-change-records-${var.central_account_id}-${var.region}-${var.environment}",
    tf_state       = "tf-state-${var.central_account_id}-${var.region}-${var.environment}",
    providers      = "tf-providers-${var.central_account_id}-${var.region}-${var.environment}",
  }

  notification_topic_arn = "arn:aws:sns:${var.region}:${var.central_account_id}:infraweave-${var.environment}"

  image_version = "v0.0.85-arm64"

  pull_through_ecr = "infraweave-ecr-public"

  runner_image     = "infraweave/runner:${local.image_version}"
  runner_image_uri = "${var.central_account_id}.dkr.ecr.${var.region}.amazonaws.com/${local.pull_through_ecr}/${local.runner_image}"

  reconciler_image     = "infraweave/reconciler-aws:${local.image_version}"
  reconciler_image_uri = "${var.central_account_id}.dkr.ecr.${var.region}.amazonaws.com/${local.pull_through_ecr}/${local.reconciler_image}"

  oidc_allowed_github_repos = flatten([
    for project in var.all_workload_projects : project.github_repos_oidc
    if project.project_id == data.aws_caller_identity.current.account_id
  ])
}

module "api" {
  count  = local.is_workload_in_central ? 0 : 1
  source = "./api"

  environment               = var.environment
  region                    = var.region
  account_id                = data.aws_caller_identity.current.account_id
  events_table_name         = local.dynamodb_table_names.events
  modules_table_name        = local.dynamodb_table_names.modules
  deployments_table_name    = local.dynamodb_table_names.deployments
  policies_table_name       = local.dynamodb_table_names.policies
  change_records_table_name = local.dynamodb_table_names.change_records
  tf_locks_table_arn        = "arn:aws:dynamodb:${var.region}:${var.central_account_id}:table/${local.dynamodb_table_names.tf_locks}"
  modules_s3_bucket         = local.bucket_names.modules
  policies_s3_bucket        = local.bucket_names.policies
  change_records_s3_bucket  = local.bucket_names.change_records
  providers_s3_bucket       = local.bucket_names.providers
  tf_state_s3_bucket        = local.bucket_names.tf_state
  subnet_id                 = length(var.subnet_ids) > 0 ? var.subnet_ids[0] : module.vpc[0].subnet_ids[0] # TODO: use both subnets
  security_group_id         = resource.aws_security_group.ecs_sg.id
  central_account_id        = var.central_account_id
  ecs_cluster_name          = aws_ecs_cluster.ecs_cluster.name
  notification_topic_arn    = local.notification_topic_arn
}

module "reconciler" {
  source = "./reconciler"

  environment                    = var.environment
  region                         = var.region
  account_id                     = data.aws_caller_identity.current.account_id
  events_table_name              = local.dynamodb_table_names.events
  modules_table_name             = local.dynamodb_table_names.modules
  deployments_table_name         = local.dynamodb_table_names.deployments
  policies_table_name            = local.dynamodb_table_names.policies
  change_records_table_name      = local.dynamodb_table_names.change_records
  modules_s3_bucket              = local.bucket_names.modules
  policies_s3_bucket             = local.bucket_names.policies
  change_records_s3_bucket       = local.bucket_names.change_records
  subnet_id                      = length(var.subnet_ids) > 0 ? var.subnet_ids[0] : module.vpc[0].subnet_ids[0] # TODO: use both subnets
  security_group_id              = resource.aws_security_group.ecs_sg.id
  central_account_id             = var.central_account_id
  driftcheck_schedule_expression = var.driftcheck_schedule_expression
  reconciler_image_uri           = local.reconciler_image_uri
}

module "oidc" {
  count  = length(local.oidc_allowed_github_repos) > 0 ? 1 : 0
  source = "./oidc"

  infraweave_env              = var.environment
  create_github_oidc_provider = var.create_github_oidc_provider
  oidc_allowed_github_repos   = local.oidc_allowed_github_repos

  providers = {
    aws = aws
  }
}

resource "aws_iam_role" "ecs_service_role" {
  name = "ecs-infraweave-${var.region}-${var.environment}-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

#trivy:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "ecs_policy" {
  name = "ecs-infraweave-${var.environment}-policy"
  role = aws_iam_role.ecs_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "*", # Intentional, needs access to manage resources when running Terraform
        ]
        Resource = "*"
      },
    ]
  })
}

data "aws_caller_identity" "current" {}

module "vpc" {
  count  = var.vpc_id != null ? 0 : 1
  source = "./vpc"

  environment = var.environment
  region      = var.region
}

resource "aws_ssm_parameter" "ecs_subnet_id" {
  name  = "/infraweave/${var.region}/${var.environment}/workload_ecs_subnet_id"
  type  = "String"
  value = length(var.subnet_ids) > 0 ? var.subnet_ids[0] : module.vpc[0].subnet_ids[0] # TODO: use both subnets
}

#trivy:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group" "ecs_sg" {
  vpc_id      = var.vpc_id != null ? var.vpc_id : module.vpc[0].vpc_id
  description = "ECS Security Group for infraweave-${var.environment}"

  # No ingress rules

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic to fetch images from ECR"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic to talk to AWS services"
  }
}

# resource "aws_vpc_endpoint" "s3" {
#   vpc_id            = aws_vpc.main.id
#   vpc_endpoint_type = "Gateway"
#   service_name      = "com.amazonaws.${var.region}.s3"

#   route_table_ids = [
#     aws_route_table.public.id
#   ]

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect    = "Allow"
#       Principal = "*"
#       Action    = ["s3:GetObject", "s3:HeadObject"]
#       Resource = "arn:aws:s3:::tf-providers-${var.central_account_id}-${var.region}-${var.environment}/*"
#     }]
#   })
# }

resource "aws_ssm_parameter" "ecs_security_group" {
  name  = "/infraweave/${var.region}/${var.environment}/workload_ecs_security_group"
  type  = "String"
  value = resource.aws_security_group.ecs_sg.id
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "terraform-ecs-cluster-${var.environment}"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ssm_parameter" "ecs_cluster_name" {
  name  = "/infraweave/${var.region}/${var.environment}/workload_ecs_cluster_name"
  type  = "String"
  value = resource.aws_ecs_cluster.ecs_cluster.name
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-${var.region}-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "terraform_task" {
  family                   = "terraform-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_service_role.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name      = "runner"
    image     = local.runner_image_uri
    cpu       = 1024
    memory    = 2048
    essential = true
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs_log_group.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
    environment = [
      {
        name  = "LOG_LEVEL"
        value = "info"
      },
      {
        name  = "ACCOUNT_ID"
        value = data.aws_caller_identity.current.account_id
      },
      {
        name  = "TF_BUCKET"
        value = local.bucket_names.tf_state
      },
      {
        name  = "TF_DYNAMODB_TABLE"
        value = "arn:aws:dynamodb:${var.region}:${var.central_account_id}:table/${local.dynamodb_table_names.tf_locks}"
      },
      {
        name  = "DYNAMODB_DEPLOYMENT_TABLE" // TODO remove?
        value = local.dynamodb_table_names.deployments
      },
      {
        name  = "DYNAMODB_EVENT_TABLE" // TODO remove?
        value = local.dynamodb_table_names.events
      },
      {
        name  = "ENVIRONMENT"
        value = var.environment
      },
      {
        name  = "INFRAWEAVE_ENV"
        value = var.environment
      },
      {
        name  = "REGION"
        value = var.region
      },
      {
        name  = "MODULE_NAME"
        value = "infraweave"
      },
      {
        name  = "RUST_BACKTRACE" // TODO remove?
        value = "1"
      }
    ]
  }])
}

resource "aws_ssm_parameter" "ecs_task_definition" {
  name  = "/infraweave/${var.region}/${var.environment}/workload_ecs_task_definition"
  type  = "String"
  value = resource.aws_ecs_task_definition.terraform_task.family
}

#trivy:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/infraweave/${var.region}/${var.environment}/runner"
  retention_in_days = 365 # Optional retention period
}


resource "aws_cloudwatch_log_resource_policy" "cross_account_read_policy" {
  policy_name = "CentralApiReadPolicy-${var.region}-${var.environment}"

  policy_document = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${var.central_account_id}"
      },
      "Action": [
        "logs:DescribeLogStreams",
        "logs:GetLogEvents"
      ],
      "Resource": "${aws_cloudwatch_log_group.ecs_log_group.arn}"
    }
  ]
}
EOF
}


######

resource "aws_iam_role" "iam_for_lambda" {
  name = "infraweave_api_read_log-${var.region}-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Principal = {
          AWS = "arn:aws:iam::${var.central_account_id}:role/infraweave_api_role-${var.region}-${var.environment}"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "infraweave_api_central_log_read_access_policy-${var.region}-${var.environment}"
  description = "IAM policy for Lambda to read and access CloudWatch Logs from central account"
  policy      = data.aws_iam_policy_document.lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    actions = [
      "logs:GetLogEvents",
    ]
    resources = [
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/infraweave/${var.region}/${var.environment}/*"
    ]
  }
}
