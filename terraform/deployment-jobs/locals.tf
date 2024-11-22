locals {
    user_provided_enpoint_configs = {
        for job in var.deployment_jobs : 
            job => 
            fileexists("${path.root}/../config/${job}/endpoint-config.json") ? jsondecode(file("${path.root}/../config/${job}/endpoint-config.json")) : null
    }
    endpoint_configs = {
        for job in var.deployment_jobs : 
            job => length(local.user_provided_enpoint_configs[job]) != null ? local.user_provided_enpoint_configs[job] : jsondecode(var.default_endpoint_config)
            
    }

    user_provided_enpoint_deployment_configs = {
        for job in var.deployment_jobs : 
            job => 
            fileexists("${path.root}/../config/${job}/endpoint-deployment-config.json") ? jsondecode(file("${path.root}/../config/${job}/endpoint-deployment-config.json")) : null
    }
    deployment_endpoint_configs = {
        for job in var.deployment_jobs : 
            job => length(local.user_provided_enpoint_deployment_configs[job]) != null ? local.user_provided_enpoint_deployment_configs[job] : jsondecode(var.default_endpoint_deployment_config)
    }
}