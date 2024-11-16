variable mlflow_tracking_uri {
    description = "URI of the MLflow tracking server"
    type    = string
}

variable deployment_jobs {
    description = "List of deployment job names to manage"
    type    = list(string)
    default = []
}

