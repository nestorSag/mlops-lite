terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.32"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = var.env_name
      Project     = "mlops-platform"
    }
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = var.vpc.cidr

  azs             = var.vpc.azs
  private_subnets = var.vpc.private_subnets
  public_subnets  = var.vpc.public_subnets
  database_subnets = var.vpc.db_subnets

  enable_nat_gateway = true
  enable_vpn_gateway = true
  create_igw = true

  tags = {
    Terraform = "true"
    Environment = var.env_name
  }
}

module "vpn-client" {
  source  = "babicamir/vpn-client/aws"
  version = "1.0.1"
  organization_name      = "OrganizationName"
  project-name           = var.project
  environment            = var.env_name
  # Network information
  vpc_id                 = module.vpc.vpc_id
  subnet_id              = module.vpc.public_subnets[0]
  client_cidr_block      = var.vpn.cidr # It must be different from the primary VPC CIDR
  # VPN config options
  split_tunnel           = "true" # or false
  vpn_inactive_period = "300" # seconds
  session_timeout_hours  = "8"
  logs_retention_in_days = "7"
  # List of users to be created
  aws-vpn-client-list    = ["root", "user-1"] #Do not delete "root" user!
}

module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  for_each = toset(
    ["mlflow-artifact-store-${data.aws_caller_identity.current.account_id}", 
    "sagemaker-endpoints-store-${data.aws_caller_identity.current.account_id}"
    ]
  )

  bucket = each.key
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = false
  }

}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name = var.project
  repository_image_tag_mutability = "IMMUTABLE"
  repository_read_write_access_arns = [data.aws_caller_identity.current.arn]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 3 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 3
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Environment = var.env_name
  }
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "mlflow-data-store"

  engine            = var.db.engine
  engine_version    = var.db.engine_version
  instance_class    = var.db.instance_class
  allocated_storage = var.db.allocated_storage
  family = var.db.family

  name  = var.db.name
  username = var.db.username
  port     = var.db.port
  manage_master_user_password = true

  # DB subnet group
  create_db_subnet_group = true
  subnet_ids             = module.vpc.database_subnets

  tags = {
    Owner       = var.project
    Environment = var.env_name
  }

}

output "master_user_secret_arn" {
  value = module.db.master_user_secret_arn
}

data "aws_secretsmanager_secret_version" "master_user_password" {
  secret_id = module.db.master_user_secret_arn
}

output "master_user_password" {
  value = jsondecode(data.aws_secretsmanager_secret_version.master_user_password.secret_string)["password"]
  sensitive = true
}

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "${var.project}-ecs-cluster"

  # cluster_configuration = {
  #   execute_command_configuration = {
  #     logging = "OVERRIDE"
  #     log_configuration = {
  #       cloud_watch_log_group_name = "/aws/ecs/aws-ec2"
  #     }
  #   }
  # }

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    mlflow-service = {
      cpu    = 1024
      memory = 4096
      container_definitions = {
        mlflow-container = {
          image = "${var.ecr_repository_url}:latest"
          environment = [
            {
              name  = "BUCKET"
              value = "mlflow-artifact-store-${data.aws_caller_identity.current.account_id}"
            },
            {
              name  = "USERNAME"
              value = var.db.username
            },
            {
              name  = "PASSWORD"
              value = module.db.master_user_password
            },
            {
              name  = "HOST"
              value = module.db.db_instance_endpoint
            },
            {
              name  = "PORT"
              value = module.db.db_instance_port
            },
            {
              name  = "DATABASE"
              value = var.db.name
            },
          ]
          essential = false
          image     = var.ecr_repository_url
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-create-group  = "true"
              awslogs-group         = "/ecs/${var.ecs_service_name}/${var.ecs_task_name}"
              awslogs-region        = var.region
              awslogs-stream-prefix = "ecs"
            }
          }
          name = var.ecs_task_name
          portMappings = [
            {
              appProtocol   = "http"
              containerPort = 8080
              hostPort      = 8080
              name          = "${var.ecs_task_name}-8080-tcp"
              protocol      = "tcp"
            },
          ]
        }
      }
    }
  }
}


####### Permissions
module "iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name        = "mlflow-server-policy"
  path        = "/"
  description = "Policy for MLflow Server in ECS"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}






# module "security_group" {
#   source  = "terraform-aws-modules/security-group/aws"
#   version = "~> 5.0"

#   name        = local.name
#   description = "Complete PostgreSQL example security group"
#   vpc_id      = module.vpc.vpc_id

#   # ingress
#   ingress_with_cidr_blocks = [
#     {
#       from_port   = 5432
#       to_port     = 5432
#       protocol    = "tcp"
#       description = "PostgreSQL access from within VPC"
#       cidr_blocks = module.vpc.vpc_cidr_block
#     },
#   ]

#   tags = local.tags
# }