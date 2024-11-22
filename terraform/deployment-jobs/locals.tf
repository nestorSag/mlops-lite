locals {
    endpoint_configs = {
        for project, version in var.deployment_jobs : 
            project => 
            jsondecode(
                fileexists("${path.root}/../config/${project}/endpoint-config.json") ? file("${path.root}/../config/${project}/endpoint-config.json") : var.default_endpoint_config
            )
    }

    deployment_endpoint_configs = {
        for project, version in var.deployment_jobs : 
            project => 
            jsondecode(
                fileexists("${path.root}/../config/${project}/endpoint-deployment-config.json") ? file("${path.root}/../config/${project}/endpoint-deployment-config.json") : var.default_endpoint_deployment_config
            )
    }
}