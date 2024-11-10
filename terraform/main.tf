terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

module "mlflow_server" {
    source = "./mlflow-server"

    db_params = var.db_params
    server_params = var.server_params
    vpc_params = var.vpc_params
    vpn_params = var.vpn_params

    region = var.region
    env_name = var.env_name
    project = var.project

    count = tobool(data.aws_ssm_parameter.build_mlflow_server.value) ? 1 : 0
}

module "training_jobs" {

  source = "./training-jobs"
  
  default_resource_requirements = var.default_resource_requirements
  compute_env_subnet_ids = var.vpc_params.private_subnets
  mlflow_tracking_uri = module.mlflow_server.mlflow_tracking_uri
  training_jobs = split(",", data.aws_ssm_parameter.training_jobs.value)
}