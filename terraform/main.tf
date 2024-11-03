terraform {
  backend "s3" {}
}

# data "terraform_remote_state" "state" {
#   backend = "s3"
#   config {
#     bucket     = "${var.state_bucket_name}"
#     region     = "${var.region}"
#     key        = "${var.project}/${var.env_name}/terraform.tfstate"
#   }
# }


provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

module "mlflow_server" {
    source = "git::https://github.com/nestorSag/terraform-aws-mlflow-server.git?ref=90ad1e8"

    db_params = var.db_params
    server_params = var.server_params
    vpc_params = var.vpc_params
    vpn_params = var.vpn_params

    region = var.region
    env_name = var.env_name
    project = var.project

    count = tobool(data.aws_ssm_parameter.build_mlflow_server.value) ? 1 : 0
}