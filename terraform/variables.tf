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

variable "state_bucket_name" {
    description = "Name of the S3 bucket to use for storing Terraform state. This variable should be set as an environmental variable with the name 'TF_VAR_state_bucket_name'."
}

variable default_resource_requirements {
    type    = list(object({
        type  = string
        value = string
    }))
    # default = [
    #     { type = "VCPU", value = "1" },
    #     { type = "MEMORY", value = "1024" }
    # ]
}

variable compute_env_subnet_ids {
    type    = list(string)
    default = []
}