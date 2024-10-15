variable "env" {
  default     = "main"
  description = "Name of the environment"
}

variable "app_name" {
  default = "mlops-platform-2024"
}

variable "region" {
  default = "us-east-1"
}

variable "ecs_service_name" {
  default = "mlflow"
}

variable "ecs_task_name" {
  default = "mlflow"
}

#### Network

variable "cidr" {
  default     = "10.0.0.0/25"
  description = "Cidr block of vpc"
}

variable "private_cidr_a" {
  default = "10.0.0.0/28"
}

variable "private_cidr_b" {
  default = "10.0.0.16/28"
}

variable "db_cidr_a" {
  default = "10.0.0.32/28"
}

variable "db_cidr_b" {
  default = "10.0.0.48/28"
}

variable "public_cidr_a" {
  default = "10.0.0.96/28"
}

variable "public_cidr_b" {
  default = "10.0.0.112/28"
}

variable "zone_a" {
  default = "us-east-1a"
}

variable "zone_b" {
  default = "us-east-1b"
}

variable "vpn_cidr" {
  default = "0.0.0.0/0"
}

variable "internet_cidr" {
  default     = "0.0.0.0/0"
  description = "Cidr block for the internet"
}