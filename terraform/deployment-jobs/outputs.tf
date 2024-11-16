output "endpoint_arns"{
    description = "The ARN of SageMaker endpoints"
    value = aws_sagemaker_endpoint.main[*].arn
}