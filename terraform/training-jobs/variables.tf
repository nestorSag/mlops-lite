variable default_training_resource_requirements {
    description = "Default resource requirements for training jobs"
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
    description = "List of subnet IDs to use for the compute environment"
    type    = list(string)
    default = []
}

variable mlflow_tracking_uri {
    description = "URI of the MLflow tracking server"
    type    = string
}

variable training_jobs {
    description = "List of training job names to manage"
    type    = list(string)
    default = []
}

variable vpc_id {
    description = "VPC ID to use for the compute environment"
    type    = string
}

variable training_jobs_iam_policy {
    description = "valid IAM policy JSON for training job containers"
    type    = string
}

variable max_vcpus {
    description = "Maximum number of vCPUs to use for training jobs"
    type    = number
}
