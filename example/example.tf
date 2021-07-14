module "some-example" {
  source = "../"
  vpc_id = var.vpc_id
  cs_id  = var.cs_id
  env    = var.env
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