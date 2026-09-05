# X-Ray Transaction Search.
#
# This is what backs the "Traces" tab on the CloudWatch Application Signals
# service page. Without it that tab stays empty no matter what the services
# emit, because it reads a different store from the classic X-Ray API — which
# is why traces can be perfectly healthy in the X-Ray console and absent here.
#
# Spans are written to a dedicated `aws/spans` log group, *not* to the services'
# own log groups, so application logs are unaffected.
#
# Scoped to the account and region, so it is declared once here rather than per
# service. Needs AWS provider >= 6.62.0, which is where these resources landed;
# before that this could only be set through the CLI.
#
# Skipped when the workload runs inside the central account: the central module
# already sets this for that account and region, and both applying it would mean
# two resources owning one setting.
# X-Ray writes spans into CloudWatch Logs on your behalf, so the log groups need
# a resource policy naming the X-Ray service principal. The console creates this
# silently when you click through Transaction Search; via the API you get a bare
# 403 from UpdateTraceSegmentDestination without it:
#
#   AccessDeniedException: XRay does not have permission to call PutLogEvents on
#   the aws/spans Log Group.
#
# The log groups do not need to exist yet — X-Ray creates them — and a resource
# policy may reference them regardless.
data "aws_iam_policy_document" "transaction_search_logs" {
  count = var.enable_transaction_search ? 1 : 0

  statement {
    sid    = "TransactionSearchXRayAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["xray.amazonaws.com"]
    }

    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
    ]

    resources = [
      "arn:${data.aws_partition.transaction_search.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:aws/spans:*",
      "arn:${data.aws_partition.transaction_search.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/application-signals/data:*",
    ]

    # Confused-deputy guards: only this account's X-Ray may use the grant.
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.transaction_search.partition}:xray:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_partition" "transaction_search" {}

resource "aws_cloudwatch_log_resource_policy" "transaction_search" {
  count = var.enable_transaction_search ? 1 : 0

  policy_name     = "TransactionSearchXRayAccess"
  policy_document = data.aws_iam_policy_document.transaction_search_logs[0].json
  region          = var.region
}

resource "aws_xray_trace_segment_destination" "this" {
  count = var.enable_transaction_search && !local.is_workload_in_central ? 1 : 0

  destination = "CloudWatchLogs"
  region      = var.region

  # Without the grant in place first, this returns 403.
  depends_on = [aws_cloudwatch_log_resource_policy.transaction_search]
}

# Indexing is the billed part of Transaction Search. Spans are still stored and
# viewable at 0%; they are just not indexed for attribute search. Pinned here so
# it cannot quietly drift upwards.
resource "aws_xray_indexing_rule" "default" {
  count = var.enable_transaction_search && !local.is_workload_in_central ? 1 : 0

  name   = "Default"
  region = var.region

  rule {
    probabilistic {
      desired_sampling_percentage = var.transaction_search_indexing_percentage
    }
  }
}
