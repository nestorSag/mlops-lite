module "s3_bucket" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-s3-bucket?ref=d8ad14f"

  bucket = "${var.project}-${var.env_name}-sagemaker-endpoint-store"
  acl    = "private"

  force_destroy = var.s3_force_destroy
  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = false
  }

}

module "ecr" {
  for_each = toset(var.deployment_jobs)
  source = "git::github.com/terraform-aws-modules/terraform-aws-ecr?ref=841b3c7"

  repository_name = "${each.key}_deployment"
  repository_image_tag_mutability = "IMMUTABLE"
  repository_force_delete = true

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 2 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 2
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "null_resource" "bundle_build_and_push_model_image" {
  for_each = var.deployment_jobs
  provisioner "local-exec" {
    command = <<-EOT
    MLFLOW_TRACKING_URI=${module.mlflow_server.mlflow_tracking_uri} \
    mlflow models build-docker \ 
        --model models:/${each.key}/${each.value} \
        --name ${module.ecr[each.key].repository_url}:v${each.value}

    aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${module.ecr[each.key].repository_url}
    docker push ${module.ecr[each.key].repository_url}:v${each.value}
    EOT
  }

  triggers = {
    # Rebuild the image if any of the files in the mlproject directory change
    project_sha = each.value
  }
}




resource "aws_iam_role" "endpoint_role" {
  name = "endpoint_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowEC2Service"
        Principal = {
          Service = "sagemaker.amazonaws.com",
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "endpoint_policy" {
  name = "test_policy"
  role = aws_iam_role.endpoint_role.id
  policy = jsonencode(
    {
        Version = "2012-10-17"
        Statement = [
            {
                Sid = "AllowSMAccess",
                Effect = "Allow",
                Action = [
                    "cloudwatch:PutMetricData",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:CreateLogGroup",
                    "logs:DescribeLogStreams",
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:ListBucket",
                    "ecr:GetAuthorizationToken",
                    "ecr:BatchCheckLayerAvailability",
                    "ecr:GetDownloadUrlForLayer",
                    "ecr:BatchGetImage"
                ],
                Resource = ["*"]
                }
            ]
        }
    )
}


resource "aws_sagemaker_model" "model" {
  for_each = var.deployment_jobs
  name = "${each.key}_model"
  execution_role_arn = aws_iam_role.endpoint_role.arn

  primary_container {
    image = "${module.ecr[each.key].repository_url}:${each.value}"
  }

  vpc_config {
    security_group_ids = var.model_security_group_ids
    subnet_ids         = module.model_subnet_ids
  }
}

resource "aws_sagemaker_endpoint_configuration" "main" {
  for_each = var.deployment_jobs
  name  = "${each.key}-${each.value}-config"
  tags  = var.tags

  dynamic "data_capture_config" {
    for_each = local.endpoint_configs[each.key]["data_capture_config"] != null ? [1] : []
    content {
      enable_capture = try(local.endpoint_configs[each.key]["data_capture_config"]["enable_capture"], null)
      destination_s3_uri = "${module.s3_bucket.bucket}/data_capture/${each.key}"
      initial_sampling_percentage = try(local.endpoint_configs[each.key]["data_capture_config"]["initial_sampling_percentage"], null)
      capture_options {
        capture_mode = try(local.endpoint_configs[each.key]["data_capture_config"]["capture_options"]["capture_mode"], null)
      }
  
    }
  }

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.model[each.key].name

    initial_instance_count = try(local.endpoint_configs[each.key]["production_variants"]["initial_instance_count"], null)
    instance_type          = try(local.endpoint_configs[each.key]["production_variants"]["instance_type"], null)
    volume_size_in_gb      = try(local.endpoint_configs[each.key]["production_variants"]["volume_size_in_gb"], null)
    inference_ami_version  = try(local.endpoint_configs[each.key]["production_variants"]["inference_ami_version"], null)

    dynamic "serverless_config" {
      for_each = local.endpoint_configs[each.key]["serverless_config"] != null ? [1] : []
      content {
        max_concurrency   = try(local.endpoint_configs[each.key]["serverless_config"]["max_concurrency"], null)
        memory_size_in_mb = try(local.endpoint_configs[each.key]["serverless_config"]["memory_size_in_mb"], null)
        provisioned_concurrenty = try(local.endpoint_configs[each.key]["serverless_config"]["provisioned_concurrenty"], null)
      }
    }

    dynamic "managed_instance_scaling" {
      for_each = local.endpoint_configs[each.key]["managed_instance_scaling"] != null ? [1] : []
      content {
        min_instance_count = try(local.endpoint_configs[each.key]["managed_instance_scaling"]["min_instance_count"], null)
        max_instance_count  = try(local.endpoint_configs[each.key]["managed_instance_scaling"]["max_instance_count"], null)
        status = try(local.endpoint_configs[each.key]["managed_instance_scaling"]["status"], null)
      }
    }

    async_inference_config {
      output_config {
        s3_output_path = "${module.s3_bucket.bucket}/async_inference/${each.key}/output"
        s3_error_path  = "${module.s3_bucket.bucket}/async_inference/${each.key}/error"
      }
    }
  }
}

resource "aws_sagemaker_endpoint" "main" {
  for_each = var.deployment_jobs
  endpoint_config_name = aws_sagemaker_endpoint_configuration.main[each.key].name
  name        = "${each.key}-endpoint"
  tags                 = var.tags
  deployment_config {

    dynamic "blue_green_update_policy" {
      for_each = local.deployment_endpoint_configs[each.key]["blue_green_update_policy"] != null ? [1] : []
      content {
        termination_wait_time_in_seconds = try(
          local.deployment_endpoint_configs[each.key]["blue_green_update_policy"]["termination_wait_time_in_seconds"], 
          null
        )
        maximum_execution_timeout_in_seconds = try(
          local.deployment_endpoint_configs[each.key]["blue_green_update_policy"]["maximum_execution_timeout_in_seconds"], 
          null
        )
        traffic_routing_configuration {
          type = try(
            local.deployment_endpoint_configs[each.key]["blue_green_update_policy"]["traffic_routing_configuration"]["type"], 
            null
          )
          wait_interval_in_seconds = try(
            local.deployment_endpoint_configs[each.key]["blue_green_update_policy"]["traffic_routing_configuration"]["wait_interval_in_seconds"], 
            null
          )
          linear_step_size = try(
            local.deployment_endpoint_configs[each.key]["blue_green_update_policy"]["traffic_routing_configuration"]["linear_step_size"], 
            null
          )
          canary_size = try(
            local.deployment_endpoint_configs[each.key]["blue_green_update_policy"]["traffic_routing_configuration"]["canary_size"], 
            null
          )
        }
        
      }
    }

    dynamic "rolling_update_policy" {
      for_each = local.deployment_endpoint_configs[each.key]["rolling_update_policy"] != null ? [1] : []
      maximum_batch_size {
        type = try(
          local.deployment_endpoint_configs[each.key]["rolling_update_policy"]["maximum_batch_size"]["type"], 
          null
        )
        value = try(
          local.deployment_endpoint_configs[each.key]["rolling_update_policy"]["maximum_batch_size"]["value"], 
          null
        )
      }
      maximum_execution_timeout_in_seconds = try(
        local.deployment_endpoint_configs[each.key]["rolling_update_policy"]["maximum_execution_timeout_in_seconds"], 
        null
      )
      wait_interval_in_seconds = try(
        local.deployment_endpoint_configs[each.key]["rolling_update_policy"]["wait_interval_in_seconds"], 
        null
      )
      dynamic "rollback_maximum_batch_size" {
        for_each = local.deployment_endpoint_configs[each.key]["rolling_update_policy"]["rollback_maximum_batch_size"] != null ? [1] : []
        content {
          type = try(
            local.deployment_endpoint_configs[each.key]["rolling_update_policy"]["rollback_maximum_batch_size"]["type"], 
            null
          )
          value = try(
            local.deployment_endpoint_configs[each.key]["rolling_update_policy"]["rollback_maximum_batch_size"]["value"], 
            null
          )
        }
      } 
    }

    # dynamic "auto_rollback_configuration" {
    #   for_each = local.deployment_endpoint_configs[each.key]["auto_rollback_configuration"] != null ? [1] : []
    #   content {
    #     alarms = [

    #     ]
    #   }
    # }
  }
}

