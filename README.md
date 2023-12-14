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
