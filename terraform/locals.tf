locals {
    tags = {
        environment = var.env_name
        project     = var.project
        terraform   = "true"
    }
    param_namespace = "${var.project}/${var.region}/${var.env_name}"
    # try to fetch jobs as comma separated string from ssm parameter store. If it fails, set it to an empty list
    training_jobs = [for job in split(",", regex("^\\[(.*)\\]$", nonsensitive(data.aws_ssm_parameter.training_jobs.value))[0]) : job if length(job) > 0]
    default_training_jobs_policy = jsonencode(
            {
        Version = "2012-10-17"
        Statement = [
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
            Resource = ["arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${local.param_namespace}/*"]
            },
            # allow access to parameter store
            {
            Effect = "Allow",
            Action = [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            Resource = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.param_namespace}/*"]
            }
        ]
        }
    )
    training_jobs_policy = fileexists("${path.root}/../policies/training-jobs-policy.json") ? file("${path.root}/../policies/training-jobs-policy.json") : local.default_training_jobs_policy
}