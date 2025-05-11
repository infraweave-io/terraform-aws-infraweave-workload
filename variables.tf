
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
