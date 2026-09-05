
resource "aws_lambda_function" "lambda" {
  function_name = "infraweave-reconciler-${var.environment}"

  timeout     = 300
  memory_size = 256

  image_uri = var.reconciler_image_uri
  role      = "arn:aws:iam::${var.account_id}:role/infraweave_reconciler_workload_role-${var.environment}"

  package_type = "Image"

  architectures = ["arm64"]

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      DYNAMODB_EVENTS_TABLE_NAME         = var.events_table_name
      DYNAMODB_MODULES_TABLE_NAME        = var.modules_table_name
      DYNAMODB_DEPLOYMENTS_TABLE_NAME    = var.deployments_table_name
      DYNAMODB_POLICIES_TABLE_NAME       = var.policies_table_name
      DYNAMODB_CHANGE_RECORDS_TABLE_NAME = var.change_records_table_name
      MODULE_S3_BUCKET                   = var.modules_s3_bucket
      POLICY_S3_BUCKET                   = var.policies_s3_bucket
      CHANGE_RECORD_S3_BUCKET            = var.change_records_s3_bucket
      REGION                             = var.region
      ENVIRONMENT                        = var.environment
      ECS_TASK_DEFINITION                = "infraweave-runner-${var.environment}"
      SUBNET_ID                          = var.subnet_id
      SECURITY_GROUP_ID                  = var.security_group_id
      CENTRAL_ACCOUNT_ID                 = var.central_account_id
      ACCOUNT_ID                         = var.account_id
      INFRAWEAVE_CENTRAL_ROLE_ARN        = "arn:aws:iam::${var.central_account_id}:role/infraweave-${var.environment}-workload-assume-role-reconciler"
      LOG_LEVEL                          = "info"
      TELEMETRY_EXPORTER                 = var.telemetry_exporter
      TELEMETRY_AWS_REGION               = var.region
      TELEMETRY_ENVIRONMENT              = var.telemetry_environment
    }
  }

  region = var.region
}

resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "infraweave_reconciler_schedule-${var.environment}"
  schedule_expression = var.driftcheck_schedule_expression

  region = var.region
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.lambda_schedule.name
  arn  = aws_lambda_function.lambda.arn

  region = var.region
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn

  region = var.region
}

data "aws_iam_policy_document" "lambda_policy_document" {
  count = var.is_primary_region ? 1 : 0

  statement {
    actions = [
      "ecr:*",
      "kms:*",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "lambda:*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "sts:TagSession",
      "sts:AssumeRole",
    ]
    resources = ["arn:aws:iam::${var.central_account_id}:role/infraweave-${var.environment}-workload-assume-role-reconciler"]
  }

  statement {
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:*:*:parameter/infraweave/${var.region}/${var.environment}/workload_ecs_cluster_name",
      "arn:aws:ssm:*:*:parameter/infraweave/${var.region}/${var.environment}/workload_ecs_subnet_id",
      "arn:aws:ssm:*:*:parameter/infraweave/${var.region}/${var.environment}/workload_ecs_security_group",
    ]
  }

  statement {
    actions = [
      "ecs:RunTask",
    ]
    resources = [
      "arn:aws:ecs:${var.region}:${var.account_id}:task-definition/infraweave-runner-${var.environment}:*",
    ]
  }

  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::${var.account_id}:role/ecsTaskExecutionRole-${var.environment}",
      "arn:aws:iam::${var.account_id}:role/ecs-infraweave-${var.environment}-service-role",
    ]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  count = var.is_primary_region ? 1 : 0

  name = "infraweave_reconciler_workload_role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  count = var.is_primary_region ? 1 : 0

  name        = "infraweave_reconciler_workload_access_policy-${var.environment}"
  description = "IAM policy for Lambda to launch CodeBuild and access CloudWatch Logs"
  policy      = data.aws_iam_policy_document.lambda_policy_document[0].json
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  count = var.is_primary_region ? 1 : 0

  role       = aws_iam_role.iam_for_lambda[0].name
  policy_arn = aws_iam_policy.lambda_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "lambda_xray_policy" {
  count = var.is_primary_region ? 1 : 0

  role       = aws_iam_role.iam_for_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}
