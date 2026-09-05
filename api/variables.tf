variable "events_table_name" {
  type = string
}

variable "modules_table_name" {
  type = string
}

variable "deployments_table_name" {
  type = string
}

variable "policies_table_name" {
  type = string
}

variable "change_records_table_name" {
  type = string
}

variable "tf_locks_table_arn" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "modules_s3_bucket" {
  type = string
}

variable "policies_s3_bucket" {
  type = string
}

variable "change_records_s3_bucket" {
  type = string
}

variable "providers_s3_bucket" {
  type = string
}

variable "tf_state_s3_bucket" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "central_account_id" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "notification_topic_arn" {
  type = string
}

variable "is_primary_region" {
  type = bool
}

variable "telemetry_exporter" {
  type        = string
  description = "Telemetry exporter for Rust services. Use \"none\" or \"aws\"."
  default     = "none"
}

variable "telemetry_environment" {
  description = "Value for the deployment.environment resource attribute, e.g. project1-prod. Application Signals builds a service identity from name, type and environment; unset, every account shares the platform default (lambda:default / ecs:default) and its services become indistinguishable in the console and in dashboard series labels."
  type        = string
  default     = ""
}
