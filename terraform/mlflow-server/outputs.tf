output "mlflow_server_endpoint" {
    description = "The endpoint of the MLflow server's load balancer."
    value       = alb.dns_name
}