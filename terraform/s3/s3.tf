resource "aws_s3_bucket" "endpoints_bucket" {
  bucket = "${var.app_name}-${var.env}-endpoints"
}

resource "aws_s3_bucket" "model_monitor_bucket" {
  bucket = "${var.app_name}-${var.env}-model-monitor"
}