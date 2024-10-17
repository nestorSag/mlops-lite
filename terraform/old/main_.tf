# main.tf

# Include the S3 module (mandatory)
module "s3" {
  source = "./s3"
  # Pass in required variables here
}

# Conditionally include the ECR module
module "ecr" {
  source = "./ecr"
  count  = var.deploy_ecr ? true : false
  # Pass in required variables here
}

module "vpn-client" {
  source  = "babicamir/vpn-client/aws"
  version = "{version}"
  organization_name      = "OrganizationName"
  project-name           = "MyProject"
  environment            = "default"
  # Network information
  vpc_id                 = "{VPC id}"
  subnet_id              = "{subnet id}"
  client_cidr_block      = "172.0.0.0/22" # It must be different from the primary VPC CIDR
  # VPN config options
  split_tunnel           = "true" # or false
  vpn_inactive_period = "300" # seconds
  session_timeout_hours  = "8"
  logs_retention_in_days = "7"
  # List of users to be created
  aws-vpn-client-list    = ["root", "user-1", "user2"] #Do not delete "root" user!
}

# Conditionally include the mlflow-server module
module "mlflow_server" {
  source = "./mlflow-server"
  count  = var.deploy_mlflow_server ? true : false
  # Pass the ECR repository URL from the ecr module
  ecr_repository_url = module.ecr[0].repository_url
}

