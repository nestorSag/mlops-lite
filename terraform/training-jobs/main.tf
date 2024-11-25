

module "ecr" {
  for_each = toset(var.training_jobs)
  source = "git::github.com/terraform-aws-modules/terraform-aws-ecr?ref=841b3c7"

  repository_name = "${each.key}_training"
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
    cp -r ./ml-projects/${each.key} ./tmp/${each.key}
    cp ./terraform/training-jobs/Dockerfile ./tmp

    aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${module.ecr[each.key].repository_url}
    docker build \
      --platform=linux/amd64 \
      -t ${module.ecr[each.key].repository_url}:${local.project_shas[each.key]} \
      --build-arg PROJECT=${each.key} \
      "./tmp"
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
        Sid    = "AllowEC2Service"
        Principal = {
          Service = "ec2.amazonaws.com",
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowAWSBatchService"
        Principal = {
          Service = "batch.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowECS"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowECSService"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "service_policy_attachment" {
  role       = aws_iam_role.service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}



resource "aws_iam_role" "task_execution_role" {
  name = "task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowEC2Service"
        Principal = {
          Service = "ec2.amazonaws.com",
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowAWSBatchService"
        Principal = {
          Service = "batch.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowECS"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowECSService"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_policy_attachment" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}



resource "aws_iam_role" "instance_role" {
  name = "instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowEC2Service"
        Principal = {
          Service = "ec2.amazonaws.com",
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowBatchService"
        Principal = {
          Service = "batch.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowECSTasks"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "instance_policy" {
  name = "test_policy"
  role = aws_iam_role.instance_role.id
  policy = var.training_jobs_iam_policy
}

resource "aws_cloudwatch_log_group" "training_jobs_log_group" {
  name = local.log_group_name
}

module "batch" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-batch?ref=c478369"

  create_service_iam_role = false
  create_instance_iam_role = false

  compute_environments = {
    TrainingJobsEnv = {
      name_prefix = "TrainingJobsEnv"

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
    TrainingJobsQueue = {
      name     = "TrainingJobsQueue"
      state    = "ENABLED"
      priority = 1
      create_scheduling_policy = false

      compute_environments = ["TrainingJobsEnv"]

      tags = {
        JobQueue = "Training jobs queue"
      }
    }
  }

  job_definitions = local.job_definitions
}
