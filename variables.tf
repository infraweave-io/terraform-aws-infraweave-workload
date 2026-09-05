
variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "central_account_id" {
  type    = string
  default = null
}

variable "driftcheck_schedule_expression" {
  type    = string
  default = "rate(2 minutes)"
}

variable "all_workload_projects" {
  description = "List of workload project names to project id + regions, github_repos should to be set when `enable_webhook_processor` is true"
  type = list(
    object({
      project_id          = string
      name                = string
      description         = string
      regions             = list(string)
      github_repos_deploy = list(string)
      github_repos_oidc   = list(string)
    })
  )
  default = []
}

variable "create_github_oidc_provider" {
  type    = bool
  default = true
}

variable "vpc_id" {
  type        = string
  default     = null
  description = "Vpc id to be used when spawning runner instances, if not set, a vpc will be created"
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "Subnets ids to be used when spawning runner instances, if not set, subnets will be created"
}

variable "is_primary_region" {
  type        = bool
  default     = false
  description = "Whether this region is the primary region for global resources such as roles and OIDC provider"
}

variable "enable_observability" {
  type        = bool
  default     = true
  description = "Enable CloudWatch Observability Access Manager link to central account"
}

variable "telemetry_exporter" {
  type        = string
  default     = "none"
  description = "Telemetry exporter for InfraWeave services that export directly (the ECS runner and the python API). Use \"none\" to disable span export or \"aws\" to export traces directly to AWS X-Ray via OTLP HTTP. The ECS runner has no collector sidecar, so \"otlp-http\" is not valid here; see reconciler_telemetry_exporter for the collector-backed Lambda."

  validation {
    condition     = contains(["none", "xray", "xray-otlp", "aws", "otlp-http", "otlp-grpc"], var.telemetry_exporter)
    error_message = "telemetry_exporter must be one of: none, xray, xray-otlp, aws, otlp-http, otlp-grpc."
  }
}

variable "reconciler_telemetry_exporter" {
  type        = string
  default     = "otlp-http"
  description = "Telemetry exporter for the reconciler Lambda. Defaults to \"otlp-http\" because the reconciler image bundles an OpenTelemetry collector extension (localhost:4318) that forwards to X-Ray. Use \"aws\" for direct export or \"none\" to disable."

  validation {
    condition     = contains(["none", "xray", "xray-otlp", "aws", "otlp-http", "otlp-grpc"], var.reconciler_telemetry_exporter)
    error_message = "reconciler_telemetry_exporter must be one of: none, xray, xray-otlp, aws, otlp-http, otlp-grpc."
  }
}

variable "runner_telemetry_exporter" {
  type        = string
  default     = "otlp-http"
  description = "Telemetry exporter for the ECS runner task. Defaults to \"otlp-http\", sending spans to the OpenTelemetry collector sidecar in the same task (localhost:4318), which forwards to X-Ray. Use \"aws\" for direct export (requires X-Ray Transaction Search) or \"none\" to disable."

  validation {
    condition     = contains(["none", "xray", "xray-otlp", "aws", "otlp-http", "otlp-grpc"], var.runner_telemetry_exporter)
    error_message = "runner_telemetry_exporter must be one of: none, xray, xray-otlp, aws, otlp-http, otlp-grpc."
  }
}


variable "central_observability_sink_arn" {
  type        = string
  default     = ""
  description = "ARN of the central CloudWatch Observability Access Manager sink to link to"
}

variable "log_retention_days" {
  type        = number
  default     = 365
  description = "Number of days to retain CloudWatch logs"
}

variable "central_output" {
  type = any
}

variable "enable_transaction_search" {
  type        = bool
  default     = false
  description = "Enable X-Ray Transaction Search for this account and region, which is what populates the Traces tab in CloudWatch Application Signals. Spans go to a dedicated aws/spans log group, not the service log groups. Off by default because it is account-wide; set telemetry_exporter to \"xray-otlp\" alongside it, since the OTLP endpoint that feeds Transaction Search requires it."
}

variable "transaction_search_indexing_percentage" {
  type        = number
  default     = 0
  description = "Percentage of spans Transaction Search indexes for attribute search. Indexing is the billed portion; at 0 spans are still stored and viewable, just not searchable by attribute."

  validation {
    condition     = var.transaction_search_indexing_percentage >= 0 && var.transaction_search_indexing_percentage <= 100
    error_message = "transaction_search_indexing_percentage must be between 0 and 100."
  }
}

variable "enable_service_level_objectives" {
  description = "Create a CloudWatch Application Signals SLO for the reconciler in this workload account."
  type        = bool
  default     = false
}

variable "slo_availability_threshold" {
  description = "Percentage of successful invocations a period must reach to count as good."
  type        = number
  default     = 99
}

variable "slo_availability_attainment" {
  description = "Ratio of good periods required over the rolling window. Loose on purpose until there is enough data to derive a real target."
  type        = number
  default     = 99
}

variable "slo_availability_warning" {
  description = "Attainment level at which the SLO is flagged as at risk."
  type        = number
  default     = 99.5
}

variable "telemetry_environment" {
  description = "Value for the deployment.environment resource attribute, e.g. project1-prod. Application Signals builds a service identity from name, type and environment; unset, every account shares the platform default (lambda:default / ecs:default) and its services become indistinguishable in the console and in dashboard series labels."
  type        = string
  default     = ""
}
