locals {
    tags = {
        environment = var.env_name
        project     = var.project
        terraform   = "true"
    }
    # try to fetch jobs as comma separated string from ssm parameter store. If it fails, set it to an empty list
    training_jobs = [for job in split(",", regex("^\\[(.*)\\]$", nonsensitive(data.aws_ssm_parameter.training_jobs.value))[0]) : job if length(job) > 0]

    # deployment locals
    deployment_jobs = jsondecode(nonsensitive(data.aws_ssm_parameter.deployment_jobs.value))
}