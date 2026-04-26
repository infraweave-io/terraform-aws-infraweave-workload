
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