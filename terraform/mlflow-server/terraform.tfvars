
region = "us-east-1"
env_name = "prod"
project = "mlops-platform"

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
    engine            = "mysql"
    engine_version    = "8.0"
    family            = "mysql8.0"
    instance_class    = "db.t3.micro"
    allocated_storage = 10
    name              = "mlflowdb"
    username          = "mlflow_db_user"
    port              = "3306"
}

mlflow_server = {
    cpu = 1024
    memory = 4096
    autoscaling_max_capacity = 2
}
