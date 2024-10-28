terraform {
  backend "s3" {
  }
}

data "terraform_remote_state" "state" {
  backend = "s3"
  config {
    bucket     = "${var.state_bucket_name}"
    region     = "${var.region}"
    key        = "${var.project}/${var.env_name}/terraform.tfstate"
  }
}

data "aws_ssm_parameter" "build_mlflow_server" {
  # values for this parameter are automatically pushed by Makefile rules
  name = "${var.state_bucket_name}/build-mlflow-server"
}

module "mlflow_server" {
    source = "./mlflow-server"

    db_params = var.db_params
    server_params = var.mlflow_server
    vpc_params = var.vpc_params
    vpn_params = var.vpn_params

    region = var.region
    env_name = var.env_name
    project = var.project

    count = tobool(data.aws_ssm_parameter.build_mlflow_server.value)
}