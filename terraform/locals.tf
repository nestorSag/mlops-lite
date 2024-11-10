locals {
    tags = {
        environment = var.env_name
        project     = var.project
        terraform   = "true"
    }

    param_namespace = "${var.project}/${var.region}/${var.env_name}"
    default_training_jobs_policy = jsonencode(
            {
        Version = "2012-10-17"
        Statement = [
            {
            sid = "AllowS3BucketAccess",
            Effect = "Allow",
            Actions = [
                "s3:GetObject",
                "s3:GetBucketLocation",
                "s3:ListBucket",
                "s3:HeadObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            Resources = ["*"]
            },
            # allow access to secrets
            {
            Effect = "Allow",
            Actions = [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:ListSecrets"
            ],
            Resources = ["arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${local.param_namespace}/*"]
            },
            # allow access to parameter store
            {
            Effect = "Allow",
            Actions = [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            Resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.param_namespace}/*"]
            }
        ]
        }
    )
    training_jobs_policy = fileexists("${path.root}/../policies/training-jobs-policy.json") ? file("${path.root}/../policies/training-jobs-policy.json") : local.default_training_jobs_policy
}