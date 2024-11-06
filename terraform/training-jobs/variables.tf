variable default_resource_requirements {
    type    = list(object({
        type  = string
        value = string
    }))
    # default = [
    #     { type = "VCPU", value = "1" },
    #     { type = "MEMORY", value = "1024" }
    # ]
}

variable compute_env_subnet_ids {
    type    = list(string)
    default = []
}

variable mlflow_tracking_uri {
    type    = string
}

variable training_jobs {
    type    = list(string)
    default = []
}