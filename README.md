# terraform-aws-infraweave-workload

Alpha version, expect changes to happen

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_all_workload_projects"></a> [all\_workload\_projects](#input\_all\_workload\_projects) | List of workload project names to project id + regions, github\_repos should to be set when `enable_webhook_processor` is true | <pre>list(<br/>    object({<br/>      project_id          = string<br/>      name                = string<br/>      description         = string<br/>      regions             = list(string)<br/>      github_repos_deploy = list(string)<br/>      github_repos_oidc   = list(string)<br/>    })<br/>  )</pre> | `[]` | no |
| <a name="input_central_account_id"></a> [central\_account\_id](#input\_central\_account\_id) | n/a | `string` | `null` | no |
| <a name="input_central_observability_sink_arn"></a> [central\_observability\_sink\_arn](#input\_central\_observability\_sink\_arn) | ARN of the central CloudWatch Observability Access Manager sink to link to | `string` | `""` | no |
| <a name="input_central_output"></a> [central\_output](#input\_central\_output) | n/a | `any` | n/a | yes |
| <a name="input_create_github_oidc_provider"></a> [create\_github\_oidc\_provider](#input\_create\_github\_oidc\_provider) | n/a | `bool` | `true` | no |
| <a name="input_driftcheck_schedule_expression"></a> [driftcheck\_schedule\_expression](#input\_driftcheck\_schedule\_expression) | n/a | `string` | `"rate(2 minutes)"` | no |
| <a name="input_enable_observability"></a> [enable\_observability](#input\_enable\_observability) | Enable CloudWatch Observability Access Manager link to central account | `bool` | `true` | no |
| <a name="input_enable_service_level_objectives"></a> [enable\_service\_level\_objectives](#input\_enable\_service\_level\_objectives) | Create a CloudWatch Application Signals SLO for the reconciler in this workload account. | `bool` | `false` | no |
| <a name="input_enable_transaction_search"></a> [enable\_transaction\_search](#input\_enable\_transaction\_search) | Enable X-Ray Transaction Search for this account and region, which is what populates the Traces tab in CloudWatch Application Signals. Spans go to a dedicated aws/spans log group, not the service log groups. Off by default because it is account-wide; set telemetry\_exporter to "xray-otlp" alongside it, since the OTLP endpoint that feeds Transaction Search requires it. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | n/a | `string` | n/a | yes |
| <a name="input_is_primary_region"></a> [is\_primary\_region](#input\_is\_primary\_region) | Whether this region is the primary region for global resources such as roles and OIDC provider | `bool` | `false` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain CloudWatch logs | `number` | `365` | no |
| <a name="input_reconciler_telemetry_exporter"></a> [reconciler\_telemetry\_exporter](#input\_reconciler\_telemetry\_exporter) | Telemetry exporter for the reconciler Lambda. Defaults to "otlp-http" because the reconciler image bundles an OpenTelemetry collector extension (localhost:4318) that forwards to X-Ray. Use "aws" for direct export or "none" to disable. | `string` | `"otlp-http"` | no |
| <a name="input_region"></a> [region](#input\_region) | n/a | `string` | n/a | yes |
| <a name="input_runner_telemetry_exporter"></a> [runner\_telemetry\_exporter](#input\_runner\_telemetry\_exporter) | Telemetry exporter for the ECS runner task. Defaults to "otlp-http", sending spans to the OpenTelemetry collector sidecar in the same task (localhost:4318), which forwards to X-Ray. Use "aws" for direct export (requires X-Ray Transaction Search) or "none" to disable. | `string` | `"otlp-http"` | no |
| <a name="input_slo_availability_attainment"></a> [slo\_availability\_attainment](#input\_slo\_availability\_attainment) | Ratio of good periods required over the rolling window. Loose on purpose until there is enough data to derive a real target. | `number` | `99` | no |
| <a name="input_slo_availability_threshold"></a> [slo\_availability\_threshold](#input\_slo\_availability\_threshold) | Percentage of successful invocations a period must reach to count as good. | `number` | `99` | no |
| <a name="input_slo_availability_warning"></a> [slo\_availability\_warning](#input\_slo\_availability\_warning) | Attainment level at which the SLO is flagged as at risk. | `number` | `99.5` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnets ids to be used when spawning runner instances, if not set, subnets will be created | `list(string)` | `[]` | no |
| <a name="input_telemetry_environment"></a> [telemetry\_environment](#input\_telemetry\_environment) | Value for the deployment.environment resource attribute, e.g. project1-prod. Application Signals builds a service identity from name, type and environment; unset, every account shares the platform default (lambda:default / ecs:default) and its services become indistinguishable in the console and in dashboard series labels. | `string` | `""` | no |
| <a name="input_telemetry_exporter"></a> [telemetry\_exporter](#input\_telemetry\_exporter) | Telemetry exporter for InfraWeave services that export directly (the ECS runner and the python API). Use "none" to disable span export or "aws" to export traces directly to AWS X-Ray via OTLP HTTP. The ECS runner has no collector sidecar, so "otlp-http" is not valid here; see reconciler\_telemetry\_exporter for the collector-backed Lambda. | `string` | `"none"` | no |
| <a name="input_transaction_search_indexing_percentage"></a> [transaction\_search\_indexing\_percentage](#input\_transaction\_search\_indexing\_percentage) | Percentage of spans Transaction Search indexes for attribute search. Indexing is the billed portion; at 0 spans are still stored and viewable, just not searchable by attribute. | `number` | `0` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Vpc id to be used when spawning runner instances, if not set, a vpc will be created | `string` | `null` | no |

## Outputs

No outputs.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.62.0 |

# Examples

Please check out the [how it is used in the bootstrap](https://github.com/infraweave-io/aws-bootstrap/blob/main/project1-dev.tf) repository for up-to-date examples if you need a custom solution.

## Resources

| Name | Type |
|------|------|
| [aws_cloudcontrolapi_resource.reconciler_availability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudcontrolapi_resource) | resource |
| [aws_cloudcontrolapi_resource.runner_availability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudcontrolapi_resource) | resource |
| [aws_cloudwatch_log_group.ecs_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_resource_policy.cross_account_read_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_resource_policy) | resource |
| [aws_cloudwatch_log_resource_policy.transaction_search](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_resource_policy) | resource |
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_task_definition.terraform_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.api_execute_runner_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.api_execute_runner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_service_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.iam_for_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ecs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.api_execute_runner_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_oam_link.workload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/oam_link) | resource |
| [aws_security_group.ecs_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.ecs_cluster_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.ecs_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.ecs_subnet_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.ecs_task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_xray_indexing_rule.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/xray_indexing_rule) | resource |
| [aws_xray_trace_segment_destination.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/xray_trace_segment_destination) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.api_execute_runner_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.transaction_search_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.transaction_search](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
