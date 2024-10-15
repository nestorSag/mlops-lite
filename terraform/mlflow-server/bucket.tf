resource "aws_s3_bucket" "mlflow_bucket" {
  bucket = "${var.app_name}-${var.env}-mlflow"
}

resource "aws_ssm_parameter" "mlflow_bucket_url" {
  name  = "/${var.app_name}/${var.env}/ARTIFACT_URL"
  type  = "SecureString"
  value = "s3://${aws_s3_bucket.mlflow_bucket.bucket}"

  tags = local.tags
}