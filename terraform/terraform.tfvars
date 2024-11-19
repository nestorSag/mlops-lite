
region = "us-east-1"
env_name = "prod"
project = "mlops-platform"

vpc_cidr_block              = "10.0.0.0/16"
vpc_private_subnets    = ["10.0.0.0/27", "10.0.0.32/27"]
vpc_public_subnets     = ["10.0.0.64/27", "10.0.0.96/27"]
vpc_db_subnets         = ["10.0.0.128/27", "10.0.0.160/27"]

vpn_cidr_block = "10.1.0.0/16"
vpn_clients = ["root", "github", "dev1"] #Do not delete "root" user!

db_instance_class    = "db.t3.micro"
db_allocated_storage = 10
db_name              = "mlflowdb"
db_username          = "mlflow_db_user"
db_port              = "3306"
db_deletion_protection = false


server_cpu = 1024
server_memory = 4096
server_autoscaling_max_capacity = 2
server_port = 5000
server_name = "mlflow_server"

s3_force_destroy = true


default_training_resource_requirements = [
    { type = "VCPU", value = "2" },
    { type = "MEMORY", value = "4096" }
]

max_vcpus = 10