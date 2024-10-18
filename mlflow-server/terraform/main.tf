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

# resource "random_password" "db_password" {
#   length           = 16
#   special          = true
#   override_special = "!#$%&*()-_=+[]{}<>:?"
# }

# module "db" {
#   source = "terraform-aws-modules/rds/aws"

#   identifier = "mlflow-data-store"

#   engine            = var.db.engine
#   engine_version    = var.db.engine_version
#   instance_class    = var.db.instance_class
#   allocated_storage = var.db.allocated_storage

#   name  = var.db.name
#   username = var.db.username
#   password = random_password.db_password.result
#   port     = var.db.port

#   # DB subnet group
#   create_db_subnet_group = true
#   subnet_ids             = module.vpc.database_subnets

#   tags = {
#     Owner       = var.project
#     Environment = var.env_name
#   }

#   family = var.db.family
# }

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