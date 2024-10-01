locals {
  name          = var.name
  environment   = var.env
  alias         = (var.alias == null) ? "${local.name}-${var.env}" : var.alias
  desired_count = var.desired_count
  health_check = merge({
    path                = "/"
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    interval            = "30"
    timeout             = "5"
    matcher             = "200"
    protocol            = "HTTP"
  }, var.health_check)
  container_definitions         = jsonencode(var.task_def)
  priority                      = var.priority
  deregistration_delay          = var.deregistration_delay
  is_log                        = var.is_log
  log_taskdefs                  = [for x in var.task_def : x if lookup(x, "logConfiguration", null) != null]
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  list_task_wtih_auto_cwlg      = local.is_log == false ? [for x in var.task_def : { for k, v in x.logConfiguration : k => v if k == var.auto_generate_cw_group_key } if try(x["logConfiguration"]["cloudwatchGroupName"], null) != null] : []
  is_fargate                    = var.launch_type == "FARGATE"
  tags                          = var.tags
}

data "aws_region" "current" {}

// is_log flag to generate aws log driver
resource "aws_cloudwatch_log_group" "this" {
  count = local.is_log == false ? 0 : length([for x in var.task_def : x])
  name = [for x in var.task_def : merge(x, { logConfiguration = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = var.name == x.name ? "/ecs/${local.alias}" : "/ecs/${var.name}-${x.name}-${var.env}",
      "awslogs-region"        = data.aws_region.current.name,
      "awslogs-stream-prefix" = "ecs"
    }
    }
  })][count.index].logConfiguration.options["awslogs-group"]
  retention_in_days = var.retention_in_days
  tags = merge({
    author = "Angle Wang"
    }, local.tags, {
    Name        = "${local.alias}-tg"
    provision   = "terraform"
    purpose     = "ecs-deployment"
    environment = local.environment
  })
}

resource "aws_cloudwatch_log_group" "customize_naming" {
  count             = length(local.list_task_wtih_auto_cwlg)
  name              = (local.list_task_wtih_auto_cwlg)[count.index][var.auto_generate_cw_group_key]
  retention_in_days = var.retention_in_days
  tags = merge({
    author = "Angle Wang"
    }, local.tags, {
    Name        = "${local.alias}-tg"
    provision   = "terraform"
    purpose     = "ecs-deployment"
    environment = local.environment
  })
}

resource "aws_ecs_task_definition" "this" {
  family = var.ecs_task_name == null ? "${local.alias}-task" : var.ecs_task_name
  container_definitions = local.is_log == false ? jsonencode(
    [for x in var.task_def : merge(x, { logConfiguration = { for k, v in lookup(x, "logConfiguration", null) : k => v if k != var.auto_generate_cw_group_key } }) if try(x["logConfiguration"], null) != null]
    ) : jsonencode([for x in var.task_def : merge(x, { logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.name == x.name ? "/ecs/${local.alias}" : "/ecs/${var.name}-${x.name}-${var.env}",
        "awslogs-region"        = data.aws_region.current.name,
        "awslogs-stream-prefix" = "ecs"
      }
      }
  })])
  requires_compatibilities = local.is_fargate ? ["FARGATE"] : null
  network_mode             = local.is_fargate ? "awsvpc" : null
  cpu                      = local.is_fargate ? var.fargate.cpu : null
  memory                   = local.is_fargate ? var.fargate.memory : null
  execution_role_arn       = var.task_exec_iam_role_arn
  task_role_arn            = var.tasks_iam_role_arn
  dynamic "runtime_platform" {
    for_each = local.is_fargate ? [{}] : []
    content {
      operating_system_family = "LINUX"
    }
  }
  dynamic "volume" {
    for_each = (var.volume == null) ? [] : [var.volume]

    content {
      dynamic "docker_volume_configuration" {
        for_each = (try(volume.value.docker_volume_configuration, null) == null) ? [] : [volume.value.docker_volume_configuration]
        content {
          autoprovision = try(docker_volume_configuration.value.autoprovision, null)
          driver_opts   = try(docker_volume_configuration.value.driver_opts, null)
          driver        = try(docker_volume_configuration.value.driver, null)
          labels        = try(docker_volume_configuration.value.labels, null)
          scope         = try(docker_volume_configuration.value.scope, null)
        }
      }

      dynamic "efs_volume_configuration" {
        for_each = (try(volume.value.efs_volume_configuration, null) == null) ? [] : [volume.value.efs_volume_configuration]
        content {
          file_system_id          = try(efs_volume_configuration.value.file_system_id, null)
          root_directory          = try(efs_volume_configuration.value.root_directory, null)
          transit_encryption      = try(efs_volume_configuration.value.transit_encryption, null)
          transit_encryption_port = try(efs_volume_configuration.value.transit_encryption_port, null)

          dynamic "authorization_config" {
            for_each = try(efs_volume_configuration.value.authorization_config, {}) != {} ? [efs_volume_configuration.value.authorization_config] : []
            content {
              access_point_id = try(efs_volume_configuration.value.authorization_config.value.access_point_id, null)
              iam             = try(efs_volume_configuration.value.authorization_config.value.iam, null)
            }
          }
        }
      }
      //TODO fsx_windows_file_server_volume_configuration
      # fsx_windows_file_server_volume_configuration = try(volume.value.fsx_windows_file_server_volume_configuration,null)
      host_path = try(volume.value.host_path, null)
      name      = volume.value.name
    }
  }
  tags = merge({
    author = "Angle Wang"
    }, local.tags, {
    Name        = "${local.alias}-tg"
    provision   = "terraform"
    purpose     = "ecs-deployment"
    environment = local.environment
  })
}


resource "aws_alb_target_group" "this" {
  count                         = var.mapping_port == 0 ? 0 : 1
  name                          = "${local.alias}-tg"
  port                          = 80
  protocol                      = "HTTP"
  vpc_id                        = var.vpc_id
  deregistration_delay          = local.deregistration_delay
  load_balancing_algorithm_type = local.load_balancing_algorithm_type
  target_type                   = local.is_fargate ? "ip" : null
  dynamic "health_check" {
    for_each = local.health_check.protocol == "TCP" ? [] : tolist([local.health_check])

    content {
      port                = "traffic-port"
      path                = local.health_check["path"]
      healthy_threshold   = local.health_check["healthy_threshold"]
      unhealthy_threshold = local.health_check["unhealthy_threshold"]
      interval            = local.health_check["interval"]
      timeout             = local.health_check["timeout"]
      protocol            = local.health_check["protocol"]
      matcher             = local.health_check["matcher"]
    }
  }
  dynamic "stickiness" {
    for_each = var.lb_stickiness == null ? [] : [var.lb_stickiness]
    content {
      cookie_duration = try(stickiness.value.cookie_duration, null)
      cookie_name     = try(stickiness.value.cookie_name, null)
      enabled         = try(stickiness.value.enabled, true)
      type            = try(stickiness.value.type, "app_cookie")
    }
  }
  tags = merge({
    author = "Angle Wang"
    }, local.tags, {
    Name        = "${local.alias}-tg"
    provision   = "terraform"
    purpose     = "ecs-deployment"
    environment = local.environment
  })
}

resource "aws_lb_listener_rule" "rule" {
  for_each     = { for i, v in var.https_listener_rules : i => v }
  listener_arn = try(var.listener_arn, null)
  priority     = try(each.value.priority, null)

  dynamic "action" {
    for_each = [for action in try(each.value.actions, []) : action if action.type == "authenticate-cognito"]

    content {
      type  = "authenticate-cognito"
      order = try(action.value.order, null)

      authenticate_cognito {
        authentication_request_extra_params = try(action.value.authentication_request_extra_params, null)
        on_unauthenticated_request          = try(action.value.on_unauthenticated_request, null)
        scope                               = try(action.value.scope, null)
        session_cookie_name                 = try(action.value.session_cookie_name, null)
        session_timeout                     = try(action.value.session_timeout, null)
        user_pool_arn                       = action.value.user_pool_arn
        user_pool_client_id                 = action.value.user_pool_client_id
        user_pool_domain                    = action.value.user_pool_domain
      }
    }
  }

  dynamic "action" {
    for_each = [for action in try(each.value.actions, []) : action if action.type == "authenticate-oidc"]

    content {
      type  = "authenticate-oidc"
      order = try(action.value.order, null)

      authenticate_oidc {
        authentication_request_extra_params = try(action.value.authentication_request_extra_params, null)
        authorization_endpoint              = action.value.authorization_endpoint
        client_id                           = action.value.client_id
        client_secret                       = action.value.client_secret
        issuer                              = action.value.issuer
        on_unauthenticated_request          = try(action.value.on_unauthenticated_request, null)
        scope                               = try(action.value.scope, null)
        session_cookie_name                 = try(action.value.session_cookie_name, null)
        session_timeout                     = try(action.value.session_timeout, null)
        token_endpoint                      = action.value.token_endpoint
        user_info_endpoint                  = action.value.user_info_endpoint
      }
    }
  }

  dynamic "action" {
    for_each = [for action in try(each.value.actions, [{
      type = "forward"
    }]) : action if action.type == "forward"]

    content {
      order            = try(action.value.order, null)
      target_group_arn = try(action.value.target_group_arn, aws_alb_target_group.this[0].arn, null)
      type             = "forward"
    }
  }

  dynamic "action" {
    for_each = [for action in try(each.value.actions, []) : action if action.type == "redirect"]

    content {
      order = try(action.value.order, null)

      redirect {
        host        = try(action.value.host, null)
        path        = try(action.value.path, null)
        port        = try(action.value.port, null)
        protocol    = try(action.value.protocol, null)
        query       = try(action.value.query, null)
        status_code = action.value.status_code
      }

      type = "redirect"
    }
  }

  dynamic "action" {
    for_each = [for action in try(each.value.actions, []) : action if action.type == "fixed-response"]

    content {
      fixed_response {
        content_type = action.value.content_type
        message_body = try(action.value.message_body, null)
        status_code  = try(action.value.status_code, null)
      }

      order = try(action.value.order, null)

      type = "fixed-response"
    }
  }

  dynamic "condition" {
    for_each = [
      for rule in each.value.conditions : rule
      if length(try(rule.host_header, rule.host_headers, [])) > 0
    ]

    content {
      host_header {
        values = try(condition.value.host_header, condition.value.host_headers)
      }
    }
  }

  dynamic "condition" {
    for_each = try(each.value.conditions, [])

    content {
      dynamic "http_header" {
        for_each = try(condition.value.http_header, condition.value.http_headers, [])

        content {
          http_header_name = http_header.value.http_header_name
          values           = http_header.value.values
        }
      }
    }
  }

  dynamic "condition" {
    for_each = [
      for rule in each.value.conditions : rule
      if length(try(rule.http_request_method, rule.http_request_methods, [])) > 0
    ]

    content {
      http_request_method {
        values = try(condition.value.http_request_method, condition.value.http_request_methods)
      }
    }
  }

  dynamic "condition" {
    for_each = [
      for rule in each.value.conditions : rule
      if length(try(rule.path_pattern, rule.path_patterns, [])) > 0
    ]

    content {
      path_pattern {
        values = try(condition.value.path_pattern, condition.value.path_patterns)
      }
    }
  }

  dynamic "condition" {
    for_each = try(each.value.conditions, [])

    content {
      dynamic "query_string" {
        for_each = try(condition.value.query_string, condition.value.query_strings, [])

        content {
          key   = try(query_string.value.key, null)
          value = query_string.value.value
        }
      }
    }
  }

  dynamic "condition" {
    for_each = [
      for rule in each.value.conditions : rule
      if length(try(rule.source_ip, rule.source_ips, [])) > 0
    ]

    content {
      source_ip {
        values = try(condition.value.source_ip, condition.value.source_ips)
      }
    }
  }

  tags = merge({
    author = "Angle Wang"
    }, local.tags, {
    Name        = "${local.alias}-tg"
    provision   = "terraform"
    purpose     = "ecs-deployment"
    environment = local.environment
  })
  depends_on = [aws_alb_target_group.this]
}

data "aws_ecs_task_definition" "this" {
  task_definition = var.ecs_task_name == null ? "${local.alias}-task" : var.ecs_task_name
  depends_on = [
    aws_ecs_task_definition.this
  ]
}

resource "aws_ecs_service" "this" {
  name    = var.ecs_service_name == null ? "${local.name}-svc" : var.ecs_service_name
  cluster = var.cs_id
  #  task_definition                    = "${aws_ecs_task_definition.this.family}:${max("${aws_ecs_task_definition.this.revision}", "${data.aws_ecs_task_definition.this.revision}")}"
  task_definition                    = "${aws_ecs_task_definition.this.family}:${max("${aws_ecs_task_definition.this.revision}", "${data.aws_ecs_task_definition.this.revision}")}"
  launch_type                        = length(var.capacity_provider_strategy) > 0 ? null : var.launch_type
  force_new_deployment               = true
  desired_count                      = local.desired_count
  deployment_maximum_percent         = local.is_fargate ? null : var.deployment_maximum_percent
  deployment_minimum_healthy_percent = local.is_fargate ? null : var.deployment_minimum_healthy_percent
  scheduling_strategy                = var.scheduling_strategy
  health_check_grace_period_seconds  = length(keys(var.service_registries)) == 0 ? (length(var.https_listener_rules) == 0 ? null : 200) : 0

  dynamic "network_configuration" {
    for_each = local.is_fargate ? [var.network_configuration] : []

    content {
      assign_public_ip = network_configuration.value.assign_public_ip
      security_groups  = network_configuration.value.security_groups
      subnets          = network_configuration.value.subnets
    }
  }
  # capacity_provider_strategy {
  #   capacity_provider = "FARGATE_SPOT"
  #   weight            = 50
  #   base              = 0
  # }
  dynamic "capacity_provider_strategy" {
    # Set by task set if deployment controller is external
    for_each = { for k, v in var.capacity_provider_strategy : k => v }

    content {
      base              = try(capacity_provider_strategy.value.base, null)
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = try(capacity_provider_strategy.value.weight, null)
    }
  }
  dynamic "ordered_placement_strategy" {
    for_each = (local.is_fargate || length(keys(var.ordered_placement_strategy)) == 0) ? [] : [var.ordered_placement_strategy]
    content {
      type  = ordered_placement_strategy.value["type"]
      field = ordered_placement_strategy.value["field"]
    }
  }

  dynamic "load_balancer" {
    for_each = var.mapping_port == 0 ? [] : [{}]
    content {
      target_group_arn = aws_alb_target_group.this[0].arn
      container_name   = (var.alias == null) ? local.name : var.alias
      container_port   = var.mapping_port
    }
  }
  # lifecycle {
  #   ignore_changes = ["task_definition"]
  # }
  # placement_constraints {
  #   type       = "memberOf"
  #   expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  # }
  dynamic "placement_constraints" {
    for_each = (local.is_fargate || length(keys(var.placement_constraints)) == 0) ? [] : [var.placement_constraints]
    content {
      type       = placement_constraints.value["type"]
      expression = placement_constraints.value["expression"]
    }
  }
  dynamic "service_connect_configuration" {
    for_each = length(var.service_connect_configuration) > 0 ? [var.service_connect_configuration] : []

    content {
      enabled = try(service_connect_configuration.value.enabled, true)

      dynamic "log_configuration" {
        for_each = try([service_connect_configuration.value.log_configuration], [])

        content {
          log_driver = try(log_configuration.value.log_driver, null)
          options    = try(log_configuration.value.options, null)

          dynamic "secret_option" {
            for_each = try(log_configuration.value.secret_option, [])

            content {
              name       = secret_option.value.name
              value_from = secret_option.value.value_from
            }
          }
        }
      }

      namespace = lookup(service_connect_configuration.value, "namespace", null)

      dynamic "service" {
        for_each = try([service_connect_configuration.value.service], [])

        content {

          dynamic "client_alias" {
            for_each = try([service.value.client_alias], [])

            content {
              dns_name = try(client_alias.value.dns_name, null)
              port     = client_alias.value.port
            }
          }

          discovery_name        = try(service.value.discovery_name, null)
          ingress_port_override = try(service.value.ingress_port_override, null)
          port_name             = service.value.port_name
        }
      }
    }
  }
  dynamic "service_registries" {
    for_each = length(keys(var.service_registries)) == 0 ? [] : [var.service_registries]
    content {
      registry_arn   = service_registries.value["registry_arn"]
      container_port = service_registries.value["container_port"]
      container_name = service_registries.value["container_name"]
    }
  }
  tags = merge({
    author = "Angle Wang"
    }, local.tags, {
    Name        = "${local.alias}-tg"
    provision   = "terraform"
    purpose     = "ecs-deployment"
    environment = local.environment
  })
}
