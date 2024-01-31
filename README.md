# A Terraform Module for AWS ECS connect to alb and cloudwatch
More easier setting ecs task to connect alb-rules and cloudwatch

## migrate 1.3.2 to 1.3.3
the "aws_alb_target_group" was created same resource when setting multiple "https_listener_rules" on 1.3.2. there is sample for duplicate resources.
```js
    {
      "module": "module.service.module.mvb-core-api",
      "mode": "managed",
      "type": "aws_alb_target_group",
      "name": "this",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {...},
        {...} // <--- should not been created
      ]
    },
```
you can run "terraform state pull > state.json" to check state file if it has duplicate resources.
![image](https://github.com/angle319/tf_ecs_alb_connector/assets/11845980/9b35e7f0-6d02-4f74-9bc5-c62d444bfeed)
```sh
terraform state list module.service | grep "aws_alb_target_group.this\[1\]"
## and remove unnecessary resource
terraform state rm 'module.service.module.mvb-core-auth.aws_alb_target_group.this[1]'
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.31.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_alb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group) | resource |
| [aws_cloudwatch_log_group.customize_naming](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_lb_listener_rule.rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_task_definition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alias"></a> [alias](#input\_alias) | n/a | `string` | `null` | no |
| <a name="input_auto_generate_cw_group_key"></a> [auto\_generate\_cw\_group\_key](#input\_auto\_generate\_cw\_group\_key) | n/a | `string` | `"cloudwatchGroupName"` | no |
| <a name="input_cs_id"></a> [cs\_id](#input\_cs\_id) | n/a | `string` | n/a | yes |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | ecs maximun healthy percent | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | ecs minimum healthy percent | `number` | `100` | no |
| <a name="input_deregistration_delay"></a> [deregistration\_delay](#input\_deregistration\_delay) | ALB deregister delay time | `number` | `30` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | task number | `number` | `1` | no |
| <a name="input_env"></a> [env](#input\_env) | n/a | `string` | n/a | yes |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check) | Health checks for Target Group | `map(any)` | <pre>{<br>  "healthy_threshold": "5",<br>  "interval": "30",<br>  "path": "/",<br>  "protocol": "HTTP",<br>  "timeout": "5",<br>  "unhealthy_threshold": "2"<br>}</pre> | no |
| <a name="input_https_listener_rules"></a> [https\_listener\_rules](#input\_https\_listener\_rules) | A list of maps describing the Listener Rules for this ALB. Required key/values: actions, conditions. Optional key/values: priority, https\_listener\_index (default to https\_listeners[count.index]) | `any` | `[]` | no |
| <a name="input_is_default_tg"></a> [is\_default\_tg](#input\_is\_default\_tg) | n/a | `bool` | `false` | no |
| <a name="input_is_log"></a> [is\_log](#input\_is\_log) | container auto aws driver with log | `bool` | `true` | no |
| <a name="input_listener_arn"></a> [listener\_arn](#input\_listener\_arn) | n/a | `string` | `""` | no |
| <a name="input_load_balancing_algorithm_type"></a> [load\_balancing\_algorithm\_type](#input\_load\_balancing\_algorithm\_type) | alb algorithm | `string` | `"round_robin"` | no |
| <a name="input_mapping_port"></a> [mapping\_port](#input\_mapping\_port) | n/a | `number` | `0` | no |
| <a name="input_name"></a> [name](#input\_name) | n/a | `string` | n/a | yes |
| <a name="input_ordered_placement_strategy"></a> [ordered\_placement\_strategy](#input\_ordered\_placement\_strategy) | ecs container order strategy | `map(string)` | <pre>{<br>  "field": "instanceId",<br>  "type": "spread"<br>}</pre> | no |
| <a name="input_placement_constraints"></a> [placement\_constraints](#input\_placement\_constraints) | ecs container constraints | `map(string)` | `{}` | no |
| <a name="input_priority"></a> [priority](#input\_priority) | n/a | `number` | `1` | no |
| <a name="input_retention_in_days"></a> [retention\_in\_days](#input\_retention\_in\_days) | task number | `number` | `14` | no |
| <a name="input_scheduling_strategy"></a> [scheduling\_strategy](#input\_scheduling\_strategy) | ecs scheduling strategy. The valid values are REPLICA and DAEMON | `string` | `"REPLICA"` | no |
| <a name="input_service_registries"></a> [service\_registries](#input\_service\_registries) | service discovery | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | <pre>{<br>  "provision": "terraform"<br>}</pre> | no |
| <a name="input_task_def"></a> [task\_def](#input\_task\_def) | n/a | `any` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | n/a | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
