
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
  type = string
  default = "rate(2 minutes)"
}

variable "organization_id" {
  type = string
  nullable = false
}
