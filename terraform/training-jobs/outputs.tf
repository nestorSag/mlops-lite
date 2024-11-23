output "compute_environments" {
  description = "Compute environments"
  value       = module.batch.compute_environments
}

output "job_queues" {
  description = "Job queues"
  value       = module.batch.job_queues
}