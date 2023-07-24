locals {
  sample_task_def = [{
    "name"              = "some-example"
    "image"             = "docker_path:tag"
    "cpu"               = 200
    "memoryReservation" = 400
    "command" : [
      "node", "index.js"
    ]
    "logConfiguration" = {
      cloudwatchGroupName ="11234"
      "logDriver"           = "fluentd",
      "options" = {
        "fluentd-address" = "10.1.100.181:24224",
        "tag"             = "ecs--uservice-mvb-teamwork-api",
      }
    }
    "environment" = [for k, v in {
      NODE_ENV = "dev"
    } : { "name" : k, "value" : v }]
  }]
}

output "get_specail_key_from_obj" {
  value = [for x in local.sample_task_def : { for k, v in x.logConfiguration : k => v if k == "cloudwatchGroupName" } if try(x["logConfiguration"]["cloudwatchGroupName"], null) != null]
}


output "filter_obj_key" {
  value = [for x in local.sample_task_def : merge(x,
    { logConfiguration = { for k, v in lookup(x, "logConfiguration", null) : k => v if k != "cloudwatchGroupName" } }

  ) if try(x["logConfiguration"]["cloudwatchGroupName"], null) != null]
}



output "get_obj_and_filter_key" {
  value = [for x in local.sample_task_def :

    { for k, v in lookup(x, "logConfiguration", null)  : k => v if k != "cloudwatchGroupName" } if try(x["logConfiguration"]["cloudwatchGroupName"], null) != null
  ]
}

output "filter_some_key" {
  value = {
    test = { for k, v in
      try(local.sample_task_def[0]["logConfiguration"], {}) 
    : k => v if k != "logDriver" } 
  }
}

  