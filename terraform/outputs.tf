output "mlflow_tracking_uri" {
  description = "URL of load balancer"
  value       = module.mlflow_server.mlflow_tracking_uri
}

output training_jobs {
  description = "Training jobs"
  value       = local.training_jobs
}