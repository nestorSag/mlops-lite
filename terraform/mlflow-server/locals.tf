locals {
    dockerfile_sha = sha1(file("${path.module}/docker/Dockerfile"))
    vpc_endpoints = {
        s3              = "Gateway",
        secretsmanager  = "Interface",
    }
}