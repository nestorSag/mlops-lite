variable mlflow_tracking_uri {
    description = "URI of the MLflow tracking server"
    type    = string
}

variable deployment_jobs {
    description = "List of deployment job names to manage"
    type    = map(string)
    default = {}
}

variable endpoint_iam_policy {
    description = "IAM policy to attach to the endpoint role"
    type    = string
}

variable default_endpoint_config {
    description = "Default endpoint configuration as a JSON string"
    type    = string
}

variable default_endpoint_deployment_config {
    description = "Default endpoint deployment configuration as a JSON string"
    type    = string
}

variable "env_name" {
    description = "Environment name, e.g. prod"
    type        = string
}

variable "project" {
    description = "Project name"
    type        = string
}

variable "s3_force_destroy" {
    description = "Allows Terraform to destroy S3 buckets even if they contain objects"
    type        = bool
}

variable "subnet_ids" {
    description = "Subnets to deploy the endpoint to"
    type        = list(string)
}

variable "model_security_group_ids" {
    description = "Security group IDs for the model"
    type        = list(string)
}