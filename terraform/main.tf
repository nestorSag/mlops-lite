terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.74.0"
      
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }

}

module "mlflow_server" {
    source = "git::https://github.com/nestorSag/terraform-aws-mlflow-server.git?ref=e6914d0"

    vpc_cidr_block         = var.vpc_cidr_block
    vpc_private_subnets    = var.vpc_private_subnets
    vpc_public_subnets     = var.vpc_public_subnets
    vpc_db_subnets         = var.vpc_db_subnets

    vpn_cidr_block = var.vpn_cidr_block
    vpn_clients    = var.vpn_clients

    db_instance_class      = var.db_instance_class
    db_allocated_storage   = var.db_allocated_storage
    db_name                = var.db_name
    db_username            = var.db_username
    db_port                = var.db_port
    db_deletion_protection = var.db_deletion_protection

    server_cpu                      = var.server_cpu
    server_memory                   = var.server_memory
    server_autoscaling_max_capacity = var.server_autoscaling_max_capacity
    server_port                     = var.server_port
    server_name                     = var.server_name

    s3_force_destroy = var.s3_force_destroy

    env_name = var.env_name
    project = var.project

}

module "training_jobs" {

  source = "./training-jobs"

  depends_on = [module.mlflow_server]
  
  default_training_resource_requirements = local.default_training_resource_requirements
  compute_env_subnet_ids = module.mlflow_server.server_subnet_ids
  
  mlflow_tracking_uri = module.mlflow_server.mlflow_tracking_uri
  vpc_id = module.mlflow_server.vpc_id

  training_jobs = local.training_jobs
  training_jobs_iam_policy = local.training_jobs_iam_policy

  max_vcpus = var.max_vcpus

}

module "deployment_jobs" {

  source = "./deployment-jobs"

  depends_on = [module.mlflow_server]

  deployment_jobs = local.deployment_jobs

  mlflow_tracking_uri = module.mlflow_server.mlflow_tracking_uri

  endpoint_iam_policy = local.endpoint_iam_policy

  default_endpoint_config = local.default_endpoint_config

  default_endpoint_deployment_config = local.default_endpoint_deployment_config

  project = var.project
  env_name = var.env_name

  s3_force_destroy = var.s3_force_destroy

  model_security_group_ids = [module.model_security_group.security_group_id]

  subnet_ids = module.mlflow_server.server_subnet_ids
}