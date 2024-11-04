data "aws_ssm_parameter" "training_jobs" {
  # values for this parameter are automatically pushed by Makefile rules
  name = "/${var.project}/${var.region}/${var.env_name}/training_jobs"
}