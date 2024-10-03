terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.4.0"
    }
  }
  backend "s3" {
    bucket = "mlops-template-tf-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
required_version = ">= 1.9.6"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}