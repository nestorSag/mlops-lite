data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "training_jobs" {
  # values for this parameter are automatically pushed by Makefile rules
  name = "/${var.project}/${var.region}/${var.env_name}/training_jobs"
}

data "aws_ssm_parameter" "deployment_jobs" {
  # values for this parameter are automatically pushed by Makefile rules
  name = "/${var.project}/${var.region}/${var.env_name}/deployment_jobs"
}