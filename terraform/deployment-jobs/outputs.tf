output "endpoint_arns"{
    description = "The ARN of SageMaker endpoints"
    value = {
        for project, version in var.deployment_jobs : project => aws_sagemaker_endpoint.main[project].arn
    }
}

output "endpoint_bucket" {
    description = "The S3 bucket where the endpoint logs are stored"
    value = module.s3_bucket.s3_bucket_arn
}