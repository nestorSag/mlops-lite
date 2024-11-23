output "mlflow_tracking_uri" {
  description = "URL of load balancer"
  value       = module.mlflow_server.mlflow_tracking_uri
}

output "training_jobs" {
  description = "Training jobs"
  value       = local.training_jobs
}

output "deployment_jobs" {
  description = "Deployment jobs"
  value       = local.deployment_jobs
}

output "endpoint_arns" {
  description = "The ARN of SageMaker endpoints"
  value = module.deployment_jobs[0].endpoint_arns
}

output "endpoint_bucket" {
  description = "The S3 bucket where the endpoint logs are stored"
  value = module.deployment_jobs[0].endpoint_bucket
}

output "compute_env_name" {
  description = "Training jobs compute environment's ARN"
  value       = module.training_jobs[0].compute_environments["fargate_compute_env"]["compute_environment_name"]
}

output "jobs_queue_name" {
  description = "Training jobs queue's ARN"
  value       = module.training_jobs[0].job_queues["training_jobs_queue"]["name"]
}
