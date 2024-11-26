locals {
  account_id             = var.central_account_id
  is_workload_in_central = var.central_account_id == data.aws_caller_identity.current.account_id

  dynamodb_table_names = {
    events         = "Events-${local.account_id}-${var.region}-${var.environment}",
    modules        = "Modules-${local.account_id}-${var.region}-${var.environment}",
    policies       = "Policies-${local.account_id}-${var.region}-${var.environment}",
    change_records = "ChangeRecords-${local.account_id}-${var.region}-${var.environment}",
    deployments    = "Deployments-${local.account_id}-${var.region}-${var.environment}",
    tf_locks       = "TerraformStateDynamoDBLocks-${var.region}-${var.environment}",
  }

  bucket_names = {
    modules        = "tf-modules-${local.account_id}-${var.region}-${var.environment}",
    policies       = "tf-policies-${local.account_id}-${var.region}-${var.environment}",
    change_records = "tf-change-records-${local.account_id}-${var.region}-${var.environment}",
    tf_state       = "tf-state-${local.account_id}-${var.region}-${var.environment}",
  }
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
  modules_s3_bucket         = local.bucket_names.modules
  policies_s3_bucket        = local.bucket_names.policies
  change_records_s3_bucket  = local.bucket_names.change_records
  subnet_id                 = resource.aws_subnet.public[0].id # TODO: use both subnets
  security_group_id         = resource.aws_security_group.ecs_sg.id
  central_account_id        = var.central_account_id
  ecs_cluster_name          = aws_ecs_cluster.ecs_cluster.name
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
  subnet_id                      = resource.aws_subnet.public[0].id # TODO: use both subnets
  security_group_id              = resource.aws_security_group.ecs_sg.id
  central_account_id             = var.central_account_id
  driftcheck_schedule_expression = var.driftcheck_schedule_expression
  reconciler_image_uri           = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/infraweave/infraweave/reconciler-aws:arm64"
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

resource "aws_iam_role_policy" "ecs_policy" {
  name = "ecs-infraweave-${var.environment}-policy"
  role = aws_iam_role.ecs_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:*",
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "sqs:sendmessage",
          "lambda:InvokeFunction",
          "*", # TODO - restrict to specific actions
        ]
        Resource = "*" # Replace with specific resources
      },
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = element(["${var.region}a", "${var.region}b"], count.index)
  map_public_ip_on_launch = true
}

resource "aws_ssm_parameter" "ecs_subnet_id" {
  name  = "/infraweave/${var.region}/${var.environment}/workload_ecs_subnet_id"
  type  = "String"
  value = resource.aws_subnet.public[0].id # TODO: use both subnets
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.main.id

  # No ingress rules

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ssm_parameter" "ecs_security_group" {
  name  = "/infraweave/${var.region}/${var.environment}/workload_ecs_security_group"
  type  = "String"
  value = resource.aws_security_group.ecs_sg.id
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "terraform-ecs-cluster-${var.environment}"
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
    image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/infraweave/infraweave/runner:arm64"
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
        name = "LOG_LEVEL"
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
        value = "arn:aws:dynamodb:${var.region}:${local.account_id}:table/${local.dynamodb_table_names.tf_locks}"
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

resource "aws_iam_policy" "user_lambda_policy" {
  name        = "infraweave_api_user_policy-${var.region}-${var.environment}"
  description = "IAM policy to use api lambda"
  policy      = data.aws_iam_policy_document.user_lambda_policy_document.json
}


data "aws_iam_policy_document" "user_lambda_policy_document" {
  statement {
    actions = [
      "lambda:*"
    ]
    resources = [
      module.api[0].api_function_arn,
    ]
  }
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
      # "logs:CreateLogGroup",
      # "logs:CreateLogStream",
      # "logs:PutLogEvents",
      "logs:GetLogEvents",
    ]
    resources = ["*"]
  }
}
