
resource "aws_lambda_function" "api" {
  function_name = "infraweave-api-${var.environment}"
  runtime       = "python3.12"
  handler       = "lambda.handler"

  timeout = 15

  filename = "${path.module}/lambda_function_payload.zip"
  role     = aws_iam_role.iam_for_lambda.arn

  source_code_hash = filebase64sha256("${path.module}/lambda_function_payload.zip")

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
      ECS_CLUSTER_NAME                   = var.ecs_cluster_name
      ECS_TASK_DEFINITION                = "terraform-task-${var.environment}"
      SUBNET_ID                          = var.subnet_id
      SECURITY_GROUP_ID                  = var.security_group_id
      CENTRAL_ACCOUNT_ID                 = var.central_account_id
      NOTIFICATION_TOPIC_ARN             = var.notification_topic_arn
    }
  }
}

data "aws_iam_policy_document" "lambda_policy_document" {

  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [var.notification_topic_arn]
  }

  statement {
    sid = "KMSAccess"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [
      "arn:aws:kms:*:${var.central_account_id}:*"
    ]
  }

  statement {
    actions = [
      "ecs:RunTask",
      "iam:PassRole",
      # "dynamodb:PutItem",
      # "dynamodb:TransactWriteItems",
      # "dynamodb:DeleteItem", # for deleting deployment dependents
      # "dynamodb:Query",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "sqs:createqueue",
      "s3:GetObject",  # for pre-signed URLs
      "s3:PutObject",  # to upload modules,
      "s3:ListBucket", # to list modules (for downloading to check diff using cli)
      "sts:TagSession",
      "sts:AssumeRole",

      "dynamodb:PutItem",
      "dynamodb:TransactWriteItems",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
    ]
    resources = ["*"]
  }

  statement {
    sid = "DeploymentsAccess"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:TransactWriteItems",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.deployments_table_name}",
    ]

    # condition {
    #   test     = "StringLike"
    #   variable = "dynamodb:LeadingKeys"
    #   values   = [
    #     "DEPLOYMENT#${var.account_id}::${var.region}::*",
    #     "PLAN#${var.account_id}::${var.region}::*",
    #     "DEPENDENT#${var.account_id}::${var.region}::*"
    #   ]
    # }
  }


  statement {
    sid = "DeploymentsAccessDeletedIndex"
    actions = [
      "dynamodb:Query",
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.deployments_table_name}/index/DeletedIndex",
      "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.deployments_table_name}/index/ModuleIndex",
    ]

    # condition {
    #   test     = "StringEquals"
    #   variable = "dynamodb:LeadingKeys"
    #   values   = [
    #     "0"
    #   ]
    # }

    # condition {
    #   test     = "ForAllValues:StringEquals"
    #   variable = "dynamodb:LeadingKeys"
    #   values   = [
    #     "0|DEPLOYMENT#${var.account_id}::${var.region}",
    #     "0|PLAN#${var.account_id}::${var.region}"
    #   ]
    # }
  }

  statement {
    sid = "EventsAccess"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:TransactWriteItems",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
    ]
    resources = ["arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.events_table_name}"]

    # condition {
    #   test     = "StringLike"
    #   variable = "dynamodb:LeadingKeys"
    #   values   = [
    #     "EVENT#${var.account_id}::${var.region}::*",
    #   ]
    # }
  }

  statement {
    sid = "ChangeRecordAccess"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:TransactWriteItems",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
    ]
    resources = ["arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.change_records_table_name}"]

    # condition {
    #   test     = "StringLike"
    #   variable = "dynamodb:LeadingKeys"
    #   values   = [
    #     "PLAN#${var.account_id}::${var.region}::*",
    #     "APPLY#${var.account_id}::${var.region}::*",
    #     "DESTROY#${var.account_id}::${var.region}::*",
    #     "UNKNOWN#${var.account_id}::${var.region}::*",
    #   ]
    # }
  }

  statement {
    sid = "ModuleAccess"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:TransactWriteItems",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${var.central_account_id}:table/${var.modules_table_name}"
    ]

    # condition {
    #   test     = "StringLike"
    #   variable = "dynamodb:LeadingKeys"
    #   values   = [
    #     "*",
    #   ]
    # }
  }

  statement {
    sid = "PolicyAccess"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:TransactWriteItems",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.policies_table_name}"
    ]

    # condition {
    #   test     = "StringLike"
    #   variable = "dynamodb:LeadingKeys"
    #   values   = [
    #     "*",
    #   ]
    # }
  }
}

resource "aws_lambda_permission" "allow_invoke_from_central_account" {
  statement_id  = "AllowInvokeFromCentralAccount"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "arn:aws:iam::${var.central_account_id}:root"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "infraweave_api_role-${var.region}-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
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
  name        = "infraweave_api_workload_access_policy-${var.region}-${var.environment}"
  description = "IAM policy for Lambda to launch CodeBuild and access CloudWatch Logs"
  policy      = data.aws_iam_policy_document.lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda.py"
  output_path = "${path.module}/lambda_function_payload.zip"
}
