variable "cs_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "env" {
  type = string
}

variable "alias" {
  type    = string
  default = null
}

variable "listener_arn" {
  type    = string
  default = ""
}

variable "name" {
  type = string
}

variable "ecs_service_name" {
  type    = string
  default = null
}

variable "ecs_task_name" {
  type    = string
  default = null
}

variable "health_check" {
  type        = map(any)
  description = "Health checks for Target Group"
  default = {
    path                = "/"
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    interval            = "30"
    timeout             = "5"
    protocol            = "HTTP"
    matcher             = "200"
  }
}
variable "https_listener_rules" {
  description = "A list of maps describing the Listener Rules for this ALB. Required key/values: actions, conditions. Optional key/values: priority, https_listener_index (default to https_listeners[count.index])"
  type        = any
  default     = []
}

variable "task_def" {
  type = any
}

variable "volume" {
  type    = any
  default = null
}

variable "priority" {
  type    = number
  default = 1
}


variable "is_default_tg" {
  type    = bool
  default = false
}

variable "mapping_port" {
  type    = number
  default = 0
}

variable "service_registries" {
  description = "service discovery"
  type        = map(string)
  default     = {}
}

variable "deregistration_delay" {
  type        = number
  description = "ALB deregister delay time"
  default     = 30
}

variable "is_log" {
  type        = bool
  description = "container auto aws driver with log"
  default     = true
}
variable "desired_count" {
  type        = number
  description = "task number"
  default     = 1
}

variable "retention_in_days" {
  type        = number
  description = "task number"
  default     = 14
}

variable "deployment_maximum_percent" {
  type        = number
  description = "ecs maximun healthy percent"
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  type        = number
  description = "ecs minimum healthy percent"
  default     = 100
}

variable "placement_constraints" {
  description = "ecs container constraints"
  type        = map(string)
  default     = {}
}

variable "ordered_placement_strategy" {
  description = "ecs container order strategy"
  type        = map(string)
  default = {
    type  = "spread"
    field = "instanceId"
  }
}

variable "load_balancing_algorithm_type" {
  description = "alb algorithm"
  type        = string
  default     = "round_robin"
}

variable "scheduling_strategy" {
  description = "ecs scheduling strategy. The valid values are REPLICA and DAEMON"
  type        = string
  default     = "REPLICA"
}

variable "auto_generate_cw_group_key" {
  default = "cloudwatchGroupName"
}

variable "tags" {
  type = map(string)
  default = {
    provision = "terraform"
  }
}

variable "lb_stickiness" {
  type    = any
  default = null
  /*
   * default = {
   *   cookie_duration = null
   *   cookie_name = null
   *   enabled = null
   *   type = null
   * }
   */
}

variable "launch_type" {
  type    = string
  default = "EC2"
}
