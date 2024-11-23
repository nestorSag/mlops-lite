module "s3_bucket" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-s3-bucket?ref=d8ad14f"

  bucket = local.bucket_name
  acl    = "private"

  force_destroy = var.s3_force_destroy
  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = false
  }

}

module "ecr" {
  for_each = var.deployment_jobs
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
    MLFLOW_TRACKING_URI=${var.mlflow_tracking_uri} mlflow models build-docker --model-uri models:/${each.key}/${each.value} --name ${module.ecr[each.key].repository_url}:${each.value}

    rm -rf ./tmp
    aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${module.ecr[each.key].repository_url}
    docker push ${module.ecr[each.key].repository_url}:${each.value}
    EOT
  }

  triggers = {
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
  policy = var.endpoint_iam_policy
}


resource "aws_sagemaker_model" "model" {
  for_each = var.deployment_jobs
  name = "${each.key}-${each.value}-model"
  execution_role_arn = aws_iam_role.endpoint_role.arn

  depends_on = [null_resource.bundle_build_and_push_model_image]

  primary_container {
    image = "${module.ecr[each.key].repository_url}:${each.value}"
  }

  vpc_config {
    security_group_ids = var.model_security_group_ids
    subnets            = var.subnet_ids
  }
}

resource "aws_sagemaker_endpoint_configuration" "main" {
  for_each = var.deployment_jobs
  name  = "${each.key}-${each.value}-config"

  depends_on = [aws_sagemaker_model.model]

  dynamic "data_capture_config" {

    for_each = lookup(
      local.endpoint_configs[each.key],
      "data_capture_config", 
      null
    ) != null ? [local.endpoint_configs[each.key]["data_capture_config"]] : []

    content {
      initial_sampling_percentage = lookup(data_capture_config.value, "initial_sampling_percentage", null)
      destination_s3_uri = "s3://${module.s3_bucket.s3_bucket_id}/data_capture/${each.key}"
      enable_capture = lookup(data_capture_config.value, "enable_capture", null)
      kms_key_id = lookup(data_capture_config.value, "kms_key_id", null)

      dynamic "capture_options" {
        for_each = lookup(
          data_capture_config.value,
          "capture_options", 
          null
        ) != null ? lookup(data_capture_config.value["capture_options"], "capture_mode", []) : []
        iterator = mode
        content {
          capture_mode = mode.value
        }
      }

      dynamic "capture_content_type_header" {
        for_each = lookup(
          data_capture_config.value,
          "capture_content_type_header", 
          null
        ) != null ? [data_capture_config.value["capture_content_type_header"]] : []

        content {
          csv_content_types  = lookup(capture_content_type_header.value, "csv_content_types", null)
          json_content_types = lookup(capture_content_type_header.value, "json_content_types", null)
        }
      }
    }
  }

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.model[each.key].name

    initial_instance_count = lookup(local.endpoint_configs[each.key]["production_variants"], "initial_instance_count", null)
    instance_type          = lookup(local.endpoint_configs[each.key]["production_variants"], "instance_type", null)
    volume_size_in_gb      = lookup(local.endpoint_configs[each.key]["production_variants"], "volume_size_in_gb", null)
    inference_ami_version  = lookup(local.endpoint_configs[each.key]["production_variants"], "inference_ami_version", null)

    dynamic "serverless_config" {
      for_each = lookup(
        local.endpoint_configs[each.key]["production_variants"],
        "serverless_config", 
        null
      ) != null ? [local.endpoint_configs[each.key]["production_variants"]["serverless_config"]] : []

      content {
        max_concurrency   = lookup(serverless_config.value, "max_concurrency", null)
        memory_size_in_mb = lookup(serverless_config.value, "memory_size_in_mb", null)
        provisioned_concurrency = lookup(serverless_config.value, "provisioned_concurrency", null)
      }

    }

    dynamic "managed_instance_scaling" {
      
      for_each = lookup(
        local.endpoint_configs[each.key]["production_variants"],
        "managed_instance_scaling", 
        null
      ) != null ? [local.endpoint_configs[each.key]["production_variants"]["managed_instance_scaling"]] : []
      
      content {
        min_instance_count = lookup(managed_instance_scaling.value, "min_instance_count", null)
        max_instance_count  = lookup(managed_instance_scaling.value, "max_instance_count", null)
        status = lookup(managed_instance_scaling.value, "status", null)
      }

    }
  }

  dynamic "async_inference_config" {
    for_each = lookup(
      local.endpoint_configs[each.key],
      "async_inference_config", 
      null
    ) != null ? [local.endpoint_configs[each.key]["async_inference_config"]] : []

    content{
      
      dynamic "output_config" {
        for_each = lookup(
          async_inference_config.value,
          "output_config", 
          null
        ) != null ? [async_inference_config.value["output_config"]] : []

        content {
          kms_key_id = lookup(output_config.value, "kms_key_id", null)
          s3_output_path = "s3://${module.s3_bucket.s3_bucket_id}/async_inference/${each.key}/output"
          s3_failure_path  = "s3://${module.s3_bucket.s3_bucket_id}/async_inference/${each.key}/error"

          dynamic "notification_config" {

            for_each = lookup(
              output_config.value,
              "notification_config", 
              null
            ) != null ? [output_config.value["notification_config"]] : []

            content {
              include_inference_response_in = lookup(notification_config.value, "include_inference_response_in", null)
              error_topic                   = lookup(notification_config.value, "error_topic", null)
              success_topic                 = lookup(notification_config.value, "success_topic", null)
            }
          }
        }
      }

      dynamic "client_config" {
        for_each = lookup(
          async_inference_config.value,
          "client_config", 
          null
        ) != null ? [async_inference_config.value["client_config"]] : []

        content {
          max_concurrent_invocations_per_instance = lookup(client_config.value, "max_concurrent_invocations_per_instance", null)
        }
      }

    }
  }
}

resource "aws_sagemaker_endpoint" "main" {
  for_each = var.deployment_jobs
  endpoint_config_name = aws_sagemaker_endpoint_configuration.main[each.key].name
  depends_on = [aws_sagemaker_endpoint_configuration.main]
  name        = "${each.key}-endpoint"
  deployment_config {

    dynamic "blue_green_update_policy" {

      for_each = lookup(
        local.deployment_endpoint_configs[each.key], 
        "blue_green_update_policy", 
        null
      ) != null ? [local.deployment_endpoint_configs[each.key]["blue_green_update_policy"]] : []

      content {
        termination_wait_in_seconds = lookup(
          blue_green_update_policy.value,
          "termination_wait_time_in_seconds", 
          null
        )
        maximum_execution_timeout_in_seconds = lookup(
          blue_green_update_policy.value,
          "maximum_execution_timeout_in_seconds", 
          null
        )
        traffic_routing_configuration {
          type = lookup(
            blue_green_update_policy.value["traffic_routing_configuration"],
            "type", 
            null
          )
          wait_interval_in_seconds = lookup(
            blue_green_update_policy.value["traffic_routing_configuration"],
            "wait_interval_in_seconds", 
            null
          )

          dynamic "linear_step_size" {
            for_each = lookup(
              blue_green_update_policy.value["traffic_routing_configuration"],
              "linear_step_size", 
              null
            ) != null ? [blue_green_update_policy.value["traffic_routing_configuration"]["linear_step_size"]] : []

            content {
              value = lookup(
                linear_step_size.value,
                "value", 
                null
              )
              type = lookup(
                linear_step_size.value,
                "type", 
                null
              )
            }
          }

          dynamic "canary_size" {
            for_each = lookup(
              blue_green_update_policy.value["traffic_routing_configuration"],
              "canary_size", 
              null
            ) != null ? [blue_green_update_policy.value["traffic_routing_configuration"]["canary_size"]] : []
            content {
              type = lookup(
                canary_size.value,
                "type", 
                null
              )
              value = lookup(
                canary_size.value,
                "value", 
                null
              )
            }
          }

        }
        
      }
    }

    dynamic "rolling_update_policy" {

      for_each = lookup(
        local.deployment_endpoint_configs[each.key], 
        "rolling_update_policy", 
        null
      ) != null ? [local.deployment_endpoint_configs[each.key]["rolling_update_policy"]] : []

      content {
        maximum_batch_size {
          type = lookup(
            rolling_update_policy.value["maximum_batch_size"],
            "type", 
            null
          )
          value = lookup(
            rolling_update_policy.value["maximum_batch_size"],
            "value", 
            null
          )
        }
        maximum_execution_timeout_in_seconds = lookup(
          rolling_update_policy.value,
          "maximum_execution_timeout_in_seconds", 
          null
        )

        wait_interval_in_seconds = lookup(
          rolling_update_policy.value,
          "wait_interval_in_seconds", 
          null
        )

        dynamic "rollback_maximum_batch_size" {
          for_each = lookup(
            rolling_update_policy.value, 
            "rollback_maximum_batch_size", 
            null
          ) != null ? [rolling_update_policy.value["rollback_maximum_batch_size"]] : []

          content {
            type = lookup(
              rollback_maximum_batch_size.value,
              "type", 
              null
            )
            value = lookup(
              rollback_maximum_batch_size.value,
              "value", 
              null
            )
          }
        } 
      }
    }
  }
}

