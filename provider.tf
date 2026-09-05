terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.62.0" # aws_xray_trace_segment_destination / aws_xray_indexing_rule
    }
  }
}
