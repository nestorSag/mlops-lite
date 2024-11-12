

module "ecr" {
  for_each = toset(var.training_jobs)
  source = "git::github.com/terraform-aws-modules/terraform-aws-ecr?ref=841b3c7"

  repository_name = each.key
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

resource "null_resource" "bundle_build_and_push_mlproject_image" {
  for_each = toset(var.training_jobs)
  provisioner "local-exec" {
    command = <<-EOT
    cd ${path.root}/..
    mkdir -p tmp
    cp Makefile tmp/
	cp -r ./ml-projects/${each.key} tmp/${each.key}
	cp ./other/docker/mlproject-template/Dockerfile tmp/Dockerfile

    aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${module.ecr[each.key].repository_url}
    docker build \
      --platform=linux/amd64 \
      -t ${module.ecr[each.key].repository_url}:${local.project_shas[each.key]} \
      "${path.module}/docker"
    docker push ${module.ecr[each.key].repository_url}:${local.project_shas[each.key]}
    EOT
  }

  triggers = {
    # Rebuild the image if any of the files in the mlproject directory change
    project_sha = local.project_shas[each.key]
  }
}


module "batch_security_group" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-security-group?ref=43798ea"

  name        = "batch-sg"
  description = "Security group for AWS Batch"
  vpc_id      = var.vpc_id

  # allow all outbound traffic
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "aws_iam_role" "service_role" {
  name = "service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "Allow AWS Batch to assume this role"
        Principal = {
          Service = "batch.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "Allow ECS tasks to assume this role"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}


resource "aws_iam_role_policy" "service_policy" {
  name = "test_policy"
  role = aws_iam_role.service_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
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
      {
        Effect = "Allow",
        Actions = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ],
        Resources = [for r in module.ecr : r.repository_arn]
      },
      {
        Effect = "Allow",
        Actions = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        Resources = ["*"]
      }

    ]
  })
}


resource "aws_iam_role" "instance_role" {
  name = "instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "Allow EC2 instances to assume this role"
        Principal = {
          Service = "ec2.amazonaws.com",
          Services = "batch.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "instance_policy" {
  name = "test_policy"
  role = aws_iam_role.instance_role.id
  policy = var.training_jobs_policy
}


module "batch" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-batch?ref=c478369"

  create_service_iam_role = false
  create_instance_iam_role = false

  compute_environments = {
    fargate_compute_env = {
      name_prefix = "fargate_compute_env"

      service_role       = aws_iam_role.service_role.arn
      instance_role      = aws_iam_role.instance_role.arn

      compute_resources = {
        type      = "FARGATE"
        max_vcpus = var.max_vcpus

        subnets            = var.compute_env_subnet_ids
        security_group_ids = [module.batch_security_group.security_group_id]

      }
    }
  }

  # Job queus and scheduling policies
  job_queues = {
    low_priority = {
      name     = "training-jobs"
      state    = "ENABLED"
      priority = 1

      compute_environments = ["fargate_compute_env"]

      tags = {
        JobQueue = "Training jobs queue"
      }
    }
  }

  job_definitions = local.job_definitions
}
