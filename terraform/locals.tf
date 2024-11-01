locals {
    tags = {
        environment = var.env_name
        project     = var.project
        terraform   = "true"
    }
}