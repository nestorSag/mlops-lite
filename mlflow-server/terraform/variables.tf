variable "vpc" {
  type = object({
    cidr               = string
    private_subnets    = list(string)
    public_subnets     = list(string)
    db_subnets         = list(string)
    azs                = list(string)
  })
}

variable "vpn" { 
    type = object({
        cidr = string
    })
}

variable "db" {
    type = object({
        engine            = string
        engine_version    = string
        instance_class    = string
        allocated_storage = number
        name              = string
        username          = string
        port              = string
        family            = string
        # iam_database_authentication_enabled = bool
        # vpc_security_group_ids = list(string)
        # maintenance_window = string
        # backup_window      = string
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