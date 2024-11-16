locals{
    # if you change this, change also in the makefile
    default_namespace = "${var.project}/${var.region}/${var.env_name}"

    # only applicable to projects where ml-projects/<project>/resource-requirements.json is not found
    default_training_resource_requirements = [
        { type = "VCPU", value = "2" },
        { type = "MEMORY", value = "4096" }
    ] 

    # used for every project
    default_training_jobs_iam_policy = jsonencode(
        {
            Version = "2012-10-17"
            Statement = [
                # allows access to s3
                {
                    Sid = "AllowS3BucketAccess",
                    Effect = "Allow",
                    Action = [
                        "s3:GetObject",
                        "s3:GetBucketLocation",
                        "s3:ListBucket",
                        "s3:HeadObject",
                        "s3:PutObject",
                        "s3:DeleteObject"
                    ],
                    Resource = ["*"]
                },
                # allow access to secrets
                {
                    Effect = "Allow",
                    Action = [
                        "secretsmanager:GetSecretValue",
                        "secretsmanager:DescribeSecret",
                        "secretsmanager:ListSecrets"
                    ],
                    Resource = ["arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${local.default_namespace}/*"]
                },
                # allow access to parameter store
                {
                    Effect = "Allow",
                    Action = [
                        "ssm:GetParameter",
                        "ssm:GetParameters",
                        "ssm:GetParametersByPath"
                    ],
                    Resource = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.default_namespace}/*"]
                }
            ]
        }
    )

    # only applicable for projects where ml-projects/<project>/endpoint-config.json is not found
    # commented values are inferred automatically by Terraform
    # Currently, only the parameters below are supported. Adding more parameters will have no effect, unless you change
    # the Terraform code in ./deployment-jobs/main.tf
    default_endpoint_config = {
        
        data_capture_config = {
            initial_sampling_percentage = 1,
            enable_capture = true,
            capture_options = {
                capture_mode = "InputAndOutput",
            }
            # destination_s3_uri = null # defined by Terraform
        }

        production_variants = {
            variant_name = "AllTraffic",

            initial_instance_count = 1,
            instance_type = "ml.t2.medium",
            volume_size_in_gb = 30,
            inference_ami_version = null,

            serverless_config = {
                max_concurrency = 100,
                memory_size_in_mb = 2048,
                provisioned_concurrenty = 100
            }

            managed_instance_scaling = {
                status = "ENABLED",
                min_instance_count = 1,
                max_instance_count = 2,
            }

        }
    }

    default_endpoint_deployment_config = {

        blue_green_update_policy = {
            traffic_routing_configuration = {
                type = "linear",
                wait_interval_in_seconds = 60,
                linear_step_size = 25
            }
            termination_wait_time_in_seconds = 0
        }
    }
}