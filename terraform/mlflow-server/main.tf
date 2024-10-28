

provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

module "vpc" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc?ref=12caf80"

  name = "my-vpc"
  cidr = var.vpc_params.cidr

  azs              = slice(data.aws_availability_zones.this.names, 0, 2)
  private_subnets  = var.vpc_params.private_subnets
  public_subnets   = var.vpc_params.public_subnets
  database_subnets = var.vpc_params.db_subnets

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


module "vpn" {
  #checkov:skip=CKV_TF_1: "Terraform AWS VPN Client module"
  source  = "babicamir/vpn-client/aws"
  version = "1.0.1"
  organization_name      = "default"
  project-name           = var.project
  environment            = var.env_name
  # Network information
  vpc_id                 = module.vpc.vpc_id
  subnet_id              = module.vpc.public_subnets[0]
  client_cidr_block      = var.vpn_params.cidr # It must be different from the primary VPC CIDR
  # VPN config options
  split_tunnel           = "true" # or false
  vpn_inactive_period = "300" # seconds
  session_timeout_hours  = "8"
  logs_retention_in_days = "7"
  # List of users to be created
  aws-vpn-client-list    = var.vpn_params.clients
}

module "db_sg" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-security-group?ref=eb9fb97"

  name        = "db"
  description = "Allows traffic from private subnets"
  vpc_id      = module.vpc.vpc_id

  # ingress_cidr_blocks      = module.vpc.private_subnets_cidr_blocks
  # ingress_rules            = ["mysql-3306-tcp"]
  ingress_with_cidr_blocks = [for subnet_cidr in var.vpc_params.private_subnets : 
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "TCP"
      description = "MySQL access from private subnets"
      cidr_blocks = subnet_cidr
    }
  ]
}


module "db" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-rds?ref=4481ddd"
  identifier = "mlflow-data-store"

  engine            = var.db_params.engine
  engine_version    = var.db_params.engine_version
  major_engine_version = var.db_params.engine_version
  instance_class    = var.db_params.instance_class
  allocated_storage = var.db_params.allocated_storage
  family = var.db_params.family

  username = var.db_params.username
  port     = var.db_params.port
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
      cidr_blocks = var.vpn_params.cidr
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      description = "HTTP access from VPC"
      cidr_blocks = var.vpc_params.cidr
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


module "ecs_task_role" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-iam.git//modules/iam-assumable-role?ref=f0e65a7"

  trusted_role_services = [
    "ecs-tasks.amazonaws.com"
  ]

  create_role = true

  role_name = "ecs-task-role"
  role_requires_mfa = false

  inline_policy_statements = [
    {
      sid = "AllowS3BucketAccess"
      actions = [
        "s3:HeadObject",
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ]
      effect    = "Allow"
      resources = [module.s3_bucket.s3_bucket_arn]
    }
  ]
}


module "ecs_cluster" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-ecs.git//modules/cluster?ref=3b70e1e" 

  cluster_name = "${var.project}-ecs-cluster"
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  tags = local.tags
}


module "ecs_service" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-ecs.git//modules/service?ref=3b70e1e"
  
  cluster_arn = module.ecs_cluster.arn
  name = "${var.project}-mlflow-service"
  depends_on = [null_resource.build_and_push_server_image, module.alb, module.db]

  create_task_exec_policy   = true
  create_task_exec_iam_role = true   
  create_tasks_iam_role = false
  tasks_iam_role_arn = module.ecs_task_role.iam_role_arn
  security_group_ids = [module.ecs_task_sg.security_group_id]
  
  cpu    = var.server_params.cpu
  memory = var.server_params.memory
  autoscaling_max_capacity = var.server_params.autoscaling_max_capacity

  subnet_ids = module.vpc.private_subnets

  container_definitions = {

    mlflow_server = {
      cpu    = var.server_cpu
      memory = var.server_memory

      image = "${module.ecr.repository_url}:${local.dockerfile_sha}"
      environment = [
        {
          name  = "BUCKET"
          value = "s3://mlflow-artifact-store-${data.aws_caller_identity.current.account_id}"
        },
        {
          name  = "USERNAME"
          value = var.db_params.username
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
          value = var.db_params.name
        },
      ]
      essential = false
      image     = "${module.ecr.repository_url}:${local.dockerfile_sha}"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-group         = "/ecs/${var.project}"
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
      name = "mlflow_server"
      portMappings = [
        {
          appProtocol   = "http"
          containerPort = 5000
          hostPort      = 5000
          name          = "http-5000-tcp"
          protocol      = "tcp"
        },
      ]
    }
  }

  load_balancer = {
    service = {
      target_group_arn = module.alb.target_groups["mlflow_server"].arn
      container_name   = "mlflow_server"
      container_port   = 5000
    }
  }
}
