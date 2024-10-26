locals {
    dockerfile_sha = sha1(file("${path.module}/docker/Dockerfile"))
    tags = {
        Environment = var.env_name
        Project     = var.project
        Terraform   = "true"
    }
}