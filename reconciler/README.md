# reconciler

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | n/a | `string` | n/a | yes |
| <a name="input_central_account_id"></a> [central\_account\_id](#input\_central\_account\_id) | n/a | `string` | n/a | yes |
| <a name="input_change_records_s3_bucket"></a> [change\_records\_s3\_bucket](#input\_change\_records\_s3\_bucket) | n/a | `string` | n/a | yes |
| <a name="input_change_records_table_name"></a> [change\_records\_table\_name](#input\_change\_records\_table\_name) | n/a | `string` | n/a | yes |
| <a name="input_deployments_table_name"></a> [deployments\_table\_name](#input\_deployments\_table\_name) | n/a | `string` | n/a | yes |
| <a name="input_driftcheck_schedule_expression"></a> [driftcheck\_schedule\_expression](#input\_driftcheck\_schedule\_expression) | n/a | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | n/a | `string` | n/a | yes |
| <a name="input_events_table_name"></a> [events\_table\_name](#input\_events\_table\_name) | n/a | `string` | n/a | yes |
| <a name="input_is_primary_region"></a> [is\_primary\_region](#input\_is\_primary\_region) | n/a | `bool` | n/a | yes |
| <a name="input_modules_s3_bucket"></a> [modules\_s3\_bucket](#input\_modules\_s3\_bucket) | n/a | `string` | n/a | yes |
| <a name="input_modules_table_name"></a> [modules\_table\_name](#input\_modules\_table\_name) | n/a | `string` | n/a | yes |
| <a name="input_policies_s3_bucket"></a> [policies\_s3\_bucket](#input\_policies\_s3\_bucket) | n/a | `string` | n/a | yes |
| <a name="input_policies_table_name"></a> [policies\_table\_name](#input\_policies\_table\_name) | n/a | `string` | n/a | yes |
| <a name="input_reconciler_image_uri"></a> [reconciler\_image\_uri](#input\_reconciler\_image\_uri) | n/a | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | n/a | `string` | n/a | yes |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | n/a | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | n/a | `string` | n/a | yes |

## Outputs

No outputs.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

# Examples

Please check out the [how it is used in the bootstrap](https://github.com/infraweave-io/aws-bootstrap/blob/main/project1-dev.tf) repository for up-to-date examples if you need a custom solution.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.lambda_schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.lambda_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_policy.lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.iam_for_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.lambda_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_iam_policy_document.lambda_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
