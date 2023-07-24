/* This sample is for create base ecs container with aws log driver */
module "some-example" {
  source = "../"
  vpc_id = "1111"
  cs_id  = "1111"
  env    = "test"
  is_log = true
  name   = "some-example"
  task_def = [{
    "name"              = "some-example"
    "image"             = "docker_path:tag"
    "cpu"               = 200
    "memoryReservation" = 400
    "command" : [
      "node", "index.js"
    ]
    "environment" = [for k, v in {
      NODE_ENV = "dev"
    } : { "name" : k, "value" : v }]
  }]
  https_listener_rules = [
    {
      conditions = [{
        path_patterns = ["/path"]
        host_headers  = ["example.domain.com"]
      }]
      priority = 901
    }
  ]
}

/* This sample is for create base ecs container without auto gen log*/
module "without-log-driver-example" {
  source = "../"
  vpc_id = "test"
  cs_id  = "test"
  env    = "test"
  is_log = false // must close auto log flag
  name   = "some-example"
  task_def = [{
    "name"              = "some-example"
    "image"             = "docker_path:tag"
    "cpu"               = 200
    "memoryReservation" = 400
    "command" : [
      "node", "index.js"
    ]
    "environment" = [for k, v in {
      NODE_ENV = "dev"
    } : { "name" : k, "value" : v }]
  }]
  https_listener_rules = [
    {
      conditions = [{
        path_patterns = ["/path"]
        host_headers  = ["example.domain.com"]
      }]
      priority = 901
    }
  ]
}

/* This sample is for create base ecs container with fluentd driver */
module "fluentd-log-driver-example" {
  source = "../"
  vpc_id = "test"
  cs_id  = "test"
  env    = "test"
  is_log = false // must close auto log flag
  name   = "some-example"
  task_def = [{
    "name"              = "some-example"
    "image"             = "docker_path:tag"
    "cpu"               = 200
    "memoryReservation" = 400
    "command" : [
      "node", "index.js"
    ]
    logConfiguration = {
      "cloudwatchGroupName" = "ok-go" // opional auto create cloud watch log group
      "logDriver" = "fluentd", 
      "options" = {
        "fluentd-address" = "10.1.100.0:24224",
        "tag"             = "ecs-myself",
      }
    }
    "environment" = [for k, v in {
      NODE_ENV = "dev"
    } : { "name" : k, "value" : v }]
  }]
  https_listener_rules = [
    {
      conditions = [{
        path_patterns = ["/path"]
        host_headers  = ["example.domain.com"]
      }]
      priority = 901
    }
  ]
}

/* This sample is for create base ecs container with fluentd driver (log group resource not auto gen)*/
module "fluentd-log-driver-without-gen-cwgroup-example" {
  source = "../"
  vpc_id = "test"
  cs_id  = "test"
  env    = "test"
  is_log = false // must close auto log flag
  name   = "some-example"
  task_def = [{
    "name"              = "some-example"
    "image"             = "docker_path:tag"
    "cpu"               = 200
    "memoryReservation" = 400
    "command" : [
      "node", "index.js"
    ]
    logConfiguration = {
      "logDriver" = "fluentd", 
      "options" = {
        "fluentd-address" = "10.1.100.0:24224",
        "tag"             = "ecs-myself",
      }
    }
    "environment" = [for k, v in {
      NODE_ENV = "dev"
    } : { "name" : k, "value" : v }]
  }]
  https_listener_rules = [
    {
      conditions = [{
        path_patterns = ["/path"]
        host_headers  = ["example.domain.com"]
      }]
      priority = 901
    }
  ]
}

