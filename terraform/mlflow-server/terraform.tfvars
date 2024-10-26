# ecs_service_name = "mlflow-service"
# ecs_task_name = "mlflow-task"
# internet_cidr = "0.0.0.0/0"
# vpn_cidr = "0.0.0.0/0"


vpc = {
  cidr               = "10.0.0.0/16"
  private_subnets    = ["10.0.0.0/27", "10.0.0.32/27"]
  public_subnets     = ["10.0.0.64/27", "10.0.0.96/27"]
  db_subnets         = ["10.0.0.128/27", "10.0.0.160/27"]
  azs                = ["us-east-1a", "us-east-1b"]
}

vpn = {
    cidr = "10.1.0.0/16"
}

db = {
    engine            = "postgres"
    engine_version    = "14"
    family            = "postgres14"
    instance_class    = "db.t3.micro"
    allocated_storage = 10
    name              = "mlflowdb"
    username          = "mlflow_db_user"
    port              = "3306"
    # iam_database_authentication_enabled = true
    # vpc_security_group_ids = ["sg-12345678"]
    # maintenance_window = "Mon:00:00-Mon:03:00"
    # backup_window      = "03:00-06:00"
}

region = "us-east-1"
env_name = "prod"
project = "mlops-platform"