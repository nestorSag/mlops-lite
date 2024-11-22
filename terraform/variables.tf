variable "region" {
  description = "AWS region to use for deployment"
  type        = string
}

variable "env_name" {
    description = "Environment name, e.g. prod"
    type        = string
}

variable "project" {
    description = "Project name"
    type        = string
}

variable "state_bucket_name" {
    description = "Name of the S3 bucket to use for storing Terraform state. This variable should be set as an environmental variable with the name 'TF_VAR_state_bucket_name'."
}

############### MLFLOW SERVER VARIABLES ################

variable "vpc_cidr_block" {
    description = "VPC CIDR block"
    type        = string
}

variable "vpc_private_subnets" {
    description = "VPC private subnets"
    type        = list(string)
}

variable "vpc_public_subnets" {
    description = "VPC public subnets"
    type        = list(string)
}

variable "vpc_db_subnets" {
    description = "VPC database subnets"
    type        = list(string)
}

variable "vpn_cidr_block" {
    description = "VPN CIDR block"
    type        = string
}

variable "vpn_clients" {
    description = "VPN client names (one per .ovpn file)"
    type        = list(string)
}

variable "db_instance_class" {
    description = "Database instance class"
    type        = string
}

variable "db_allocated_storage" {
    description = "Database allocated storage"
    type        = number
}

variable "db_name" {
    description = "Database name"
    type        = string
}

variable "db_username" {
    description = "Database username"
    type        = string
}

variable "db_port" {
    description = "Database port"
    type        = string
}

variable "db_deletion_protection" {
    description = "Database deletion protection"
    type        = bool
}

variable "s3_force_destroy" {
    description = "Allows Terraform to destroy S3 buckets even if they contain objects"
    type        = bool
}

variable "server_cpu" {
    description = "MLflow server CPU"
    type        = number
}

variable "server_memory" {
    description = "MLflow server memory"
    type        = number
}

variable "server_autoscaling_max_capacity" {
    description = "MLflow server autoscaling max capacity"
    type        = number
}

variable "server_port" {
    description = "MLflow server port"
    type        = number
}

variable "server_name" {
    description = "MLflow server name"
    type        = string
}


############### TRAINING JOBS VARIABLES ################

variable max_vcpus {
    description = "Maximum number of vCPUs to use for training jobs"
    type        = number
}

############### DEPLOYMENT JOBS VARIABLES ################