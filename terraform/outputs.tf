# outputs.tf
output "s3_bucket" {
  value = module.s3.s3_bucket_name
}

output "ecr_url" {
  value = module.ecr[0].ecr_repository_url
  condition = var.deploy_ecr
}

output "mlflow_url" {
  value = module.mlflow_server[0].mlflow_service_url
  condition = var.deploy_mlflow_server
}