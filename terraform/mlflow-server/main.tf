terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.32"
    }
  }
  backend "s3" {}

}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

module "vpc" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc?ref=12caf80"

  name = "my-vpc"
  cidr = var.vpc.cidr

  azs              = slice(data.aws_availability_zones.this.names, 0, 2)
  private_subnets  = var.vpc.private_subnets
  public_subnets   = var.vpc.public_subnets
  database_subnets = var.vpc.db_subnets

  enable_nat_gateway = false
  enable_vpn_gateway = true
  map_public_ip_on_launch = false
  one_nat_gateway_per_az  = false

  enable_dns_hostnames    = true
  enable_dns_support      = true
  create_igw              = false

}

module "vpc_endpoints_sg" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-security-group?ref=eb9fb97"

  name        = "vpc-endpoint"
  description = "Allow traffic from within vpc"
  vpc_id      = module.vpc.vpc_id

  # ingress_cidr_blocks      = [module.vpc.vpc_cidr_block]
  # ingress_rules            = ["https-443-tcp"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "TCP"
      description = "Allow HTTPS connection towards vpc endpoint"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]
}

resource "aws_vpc_endpoint" "vpce" {
  for_each = local.vpc_endpoints

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type = each.value

  route_table_ids     = each.value == "Gateway" ? concat([module.vpc.default_route_table_id], module.vpc.private_route_table_ids) : []
  private_dns_enabled = each.value == "Interface" # enable private DNS for interface endpoints
  security_group_ids  = each.value == "Interface" ? [module.vpc_endpoints_sg.security_group_id] : []
  subnet_ids          = each.value == "Interface" ? module.vpc.private_subnets : []
}

module "s3_bucket" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-s3-bucket?ref=d8ad14f"

  bucket = "mlflow-artifact-store-${data.aws_caller_identity.current.account_id}"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = false
  }

}

module "ecr" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-ecr?ref=841b3c7"

  repository_name = "mlflow-server"
  repository_image_tag_mutability = "IMMUTABLE"
  repository_read_write_access_arns = [data.aws_caller_identity.current.arn]
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


resource "null_resource" "build_and_push_server_image" {
  provisioner "local-exec" {
    command = <<-EOT
    aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${module.ecr.repository_url}
    docker build \
      --platform=linux/amd64 \
      -t ${module.ecr.repository_url}:${local.dockerfile_sha} \
      "${path.module}/docker"
    docker push ${module.ecr.repository_url}:${local.dockerfile_sha}
    EOT
  }

  triggers = {
    dockerfile_sha = local.dockerfile_sha
  }
}


module "vpn-client" {
  #checkov:skip=CKV_TF_1: "Terraform AWS VPN Client module"
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
  aws-vpn-client-list    = ["root", "github", "dev1"] #Do not delete "root" user!
}

module "db_sg" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-security-group?ref=eb9fb97"

  name        = "db"
  description = "Allows traffic from private subnets"
  vpc_id      = module.vpc.vpc_id

  # ingress_cidr_blocks      = module.vpc.private_subnets_cidr_blocks
  # ingress_rules            = ["mysql-3306-tcp"]
  ingress_with_cidr_blocks = [for subnet_cidr in var.vpc.private_subnets : 
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "TCP"
      description = "MySQL access from private subnets"
      cidr_blocks = [subnet_cidr]
    }
  ]
}


module "db" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-rds?ref=4481ddd"
  identifier = "mlflow-data-store"

  engine            = var.db.engine
  engine_version    = var.db.engine_version
  major_engine_version = var.db.engine_version
  instance_class    = var.db.instance_class
  allocated_storage = var.db.allocated_storage
  family = var.db.family

  username = var.db.username
  port     = var.db.port
  manage_master_user_password = true

  # DB subnet group
  create_db_subnet_group     =  true
  subnet_ids                 =  module.vpc.database_subnets
  vpc_security_group_ids = [module.db_sg.security_group_id]


}


data "aws_secretsmanager_secret_version" "master_user_password" {
  secret_id = module.db.db_instance_master_user_secret_arn
}

locals {
  db_password = jsondecode(data.aws_secretsmanager_secret_version.master_user_password.secret_string)["password"]
}



module "alb_sg" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-security-group?ref=eb9fb97"

  name        = "alb"
  description = "Allows traffic from VPN and VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      description = "HTTP access from VPN"
      cidr_blocks = module.vpn.vpn_cidr_blocks
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      description = "HTTP access from VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]
}

module "alb" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-alb?ref=5121d71"

  name    = "mlflow-server-lb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
  load_balancer_type = "application"

  security_groups = [module.alb_sg.security_group_id]

  access_logs = {
    bucket = "mlflow-server-lb-logs-${data.aws_caller_identity.current.account_id}"
  }

  listeners = {
    mlflow-server-http-forward = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "mlflow_server"
      }
    }
  }

  target_groups = {
    mlflow_server = {
      backend_protocol = "HTTP"
      backend_port     = 5000
      target_type      = "ip"
      create_attachment = false
    }
  }

}


module "ecs_task_sg" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-security-group?ref=eb9fb97"

  name        = "ecs_task"
  description = "Allows traffic from LB"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port   = 5000
      to_port     = 5000
      protocol    = "TCP"
      description = "MLflow server access from LB"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
}


module "ecs" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-ecs?ref=3b70e1e"
  depends_on = [null_resource.build_and_push_server_image, module.alb, module.db]

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    mlflow-service = {

      create_tasks_iam_role = false
      tasks_iam_role_arn = aws_iam_role.ecs_task_role.arn

      create_iam_role = false
      

      cpu    = 1024
      memory = 4096
      container_definitions = {

        mlflow_server = {
          image = "${module.ecr.repository_url}:latest"
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
              value = local.db_password
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
          image     = "${var.ecr_repository_url}:latest"
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-create-group  = "true"
              awslogs-group         = "/ecs/${var.ecs_service_name}/${var.ecs_task_name}"
              awslogs-region        = data.aws_region.current.name
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
      load_balancer = {
        service = {
          target_group_arn = module.alb.target_group_arns["mlflow_server"]
          container_name   = "mlflow_server"
          container_port   = 5000
        }
      }
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs_task_role"

  policy = templatefile("${path.module}/policies/ecs_task_policy.json", {
    s3_bucket_arn  = module.s3_bucket.bucket_arn
  })

}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name = "ecs_execution_role_policy"
  role = aws_iam_role.ecs_execution_role.id
  policy = templatefile("${path.module}/policies/ecs_execution_policy.json", {
    aws_region = data.aws_region.current.name
    account_id = data.aws_caller_identity.current.account_id
    ecs_service_name = "mlflow-service"
    target_group_arn = module.alb.target_group_arns["mlflow_server"]
  })
}

