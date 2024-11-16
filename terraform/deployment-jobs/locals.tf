locals {
    user_provided_enpoint_configs = {
        for job in var.deployment_jobs : 
            job => 
            fileexists("${path.root}/../config/${job}/endpoint-config.json") ? jsondecode(file("${path.root}/../config/${job}/endpoint-config.json")) : tomap({})
    }
    endpoint_configs = {
        for job in var.deployment_jobs : 
            job => length(local.user_provided_enpoint_configs[job]) > 0 ? local.user_provided_enpoint_configs[job] : var.default_endpoint_config
            
    }

    user_provided_enpoint_deployment_configs = {
        for job in var.deployment_jobs : 
            job => 
            fileexists("${path.root}/../config/${job}/endpoint-deployment-config.json") ? jsondecode(file("${path.root}/../config/${job}/endpoint-deployment-config.json")) : tomap({})
    }
    deployment_endpoint_configs = {
        for job in var.deployment_jobs : 
            job => length(local.user_provided_enpoint_deployment_configs[job]) > 0 ? local.user_provided_enpoint_deployment_configs[job] : var.default_endpoint_deployment_config
    }
}