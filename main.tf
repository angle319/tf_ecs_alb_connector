locals {
  name          = var.name
  environment   = var.env
  alias         = "${local.name}-${var.env}"
  desired_count = var.desired_count
  health_check = merge({
    path                = "/"
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    interval            = "30"
    timeout             = "5"
    protocol            = "HTTP"
  }, var.health_check)
  container_definitions = jsonencode(var.task_def)
  priority              = var.priority
  deregistration_delay  = var.deregistration_delay
  is_log                = var.is_log
  log_taskdefs          = [for x in var.task_def : x if lookup(x, "logConfiguration", null) != null]
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  #count = length(var.task_def)
  count = length(local.is_log == false ? local.log_taskdefs : [for x in var.task_def : merge(x, { logConfiguration = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = "/ecs/${var.name}-${var.env}",
      "awslogs-region"        = data.aws_region.current.name,
      "awslogs-stream-prefix" = "ecs"
    }
    }
  })])
  name = (local.is_log == false ? local.log_taskdefs : [for x in var.task_def : merge(x, { logConfiguration = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = "/ecs/${var.name}-${var.env}",
      "awslogs-region"        = data.aws_region.current.name,
      "awslogs-stream-prefix" = "ecs"
    }
    }
  })])[count.index].logConfiguration.options["awslogs-group"]
  retention_in_days = var.retention_in_days
  tags = {
    Name        = "${local.alias}-tg"
    author      = "angle"
    provision   = "terraform"
    purpose     = "ecs-deployment"
    environment = local.environment
  }
}

resource "aws_ecs_task_definition" "this" {
  family = "${local.alias}-task"
  container_definitions = local.is_log == false ? local.container_definitions : jsonencode([for x in var.task_def : merge(x, { logConfiguration = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = "/ecs/${var.name}-${var.env}",
      "awslogs-region"        = data.aws_region.current.name,
      "awslogs-stream-prefix" = "ecs"
    }
    }
  })])
}


resource "aws_alb_target_group" "this" {
  count                = length(var.https_listener_rules)
  name                 = "${local.alias}-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = local.deregistration_delay
  load_balancing_algorithm_type = local.load_balancing_algorithm_type
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
    }
  }

  tags = {
    Name        = "${local.alias}-tg"
    author      = "angle"
    provision   = "terraform"
    purpose     = "ecs-deployment"
    environment = local.environment
  }
}

resource "aws_lb_listener_rule" "rule" {
  count        = length(var.https_listener_rules)
  listener_arn = var.listener_arn
  priority     = lookup(var.https_listener_rules[count.index], "priority", null)

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.this[0].arn
  }

  # Path Pattern condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "path_patterns", [])) > 0
    ]

    content {
      path_pattern {
        values = condition.value["path_patterns"]
      }
    }
  }

  # Host header condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "host_headers", [])) > 0
    ]

    content {
      host_header {
        values = condition.value["host_headers"]
      }
    }
  }

  # Http header condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "http_headers", [])) > 0
    ]

    content {
      dynamic "http_header" {
        for_each = condition.value["http_headers"]

        content {
          http_header_name = http_header.value["http_header_name"]
          values           = http_header.value["values"]
        }
      }
    }
  }

  # Http request method condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "http_request_methods", [])) > 0
    ]

    content {
      http_request_method {
        values = condition.value["http_request_methods"]
      }
    }
  }

  # Query string condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "query_strings", [])) > 0
    ]

    content {
      dynamic "query_string" {
        for_each = condition.value["query_strings"]

        content {
          key   = lookup(query_string.value, "key", null)
          value = query_string.value["value"]
        }
      }
    }
  }

  # Source IP address condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "source_ips", [])) > 0
    ]

    content {
      source_ip {
        values = condition.value["source_ips"]
      }
    }
  }
}

data "aws_ecs_task_definition" "this" {
  task_definition = "${local.alias}-task"
  depends_on = [
    aws_ecs_task_definition.this
  ]
}

resource "aws_ecs_service" "this" {
  name    = "${local.name}-svc"
  cluster = var.cs_id
  #  task_definition                    = "${aws_ecs_task_definition.this.family}:${max("${aws_ecs_task_definition.this.revision}", "${data.aws_ecs_task_definition.this.revision}")}"
  task_definition                    = "${aws_ecs_task_definition.this.family}:${max("${aws_ecs_task_definition.this.revision}", "${data.aws_ecs_task_definition.this.revision}")}"
  desired_count                      = local.desired_count
  force_new_deployment               = true
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  health_check_grace_period_seconds  = length(keys(var.service_registries)) == 0 ? (length(var.https_listener_rules) == 0 ? null : 200) : 0

  dynamic "ordered_placement_strategy" {
    for_each = length(keys(var.ordered_placement_strategy)) == 0 ? [] : [var.ordered_placement_strategy]
    content {
      type  = ordered_placement_strategy.value["type"]
      field = ordered_placement_strategy.value["field"]
    }
  }

  dynamic "load_balancer" {
    for_each = var.mapping_port == 0 ? [] : [{}]
    content {
      target_group_arn = aws_alb_target_group.this[0].arn
      container_name   = local.name
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
    for_each = length(keys(var.placement_constraints)) == 0 ? [] : [var.placement_constraints]
    content {
      type       = placement_constraints.value["type"]
      expression = placement_constraints.value["expression"]
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
}
