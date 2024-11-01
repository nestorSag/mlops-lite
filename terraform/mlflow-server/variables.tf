variable "vpc_params" {
  description = "VPC configuration parameters"
  type = object({
    cidr               = string
    private_subnets    = list(string)
    public_subnets     = list(string)
    db_subnets         = list(string)
    azs                = list(string)
  })
}

variable "vpn_params" { 
    description = "VPN configuration parameters"
    type = object({
        cidr = string
        clients = list(string) # This list must always start with a 'root' element.
    })
}

variable "db_params" {
    description = "Database configuration parameters"
    type = object({
        engine            = string
        engine_version    = string
        instance_class    = string
        allocated_storage = number
        name              = string
        username          = string
        port              = string
        family            = string
    })
}

variable "server_params" {
    description = "MLflow server configuration parameters"
    type = object({
        cpu = number
        memory = number
        autoscaling_max_capacity = number
        port = number
        name = string
    })
}

variable "region" {
  description = "AWS region to use for deployment"
  type        = string
}

variable "env_name" {
    description = "Environment name"
    type        = string
}

variable "project" {
    description = "Project name"
    type        = string
}