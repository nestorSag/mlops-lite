locals {
    job_definitions = {
        for job in var.training_jobs : job => {
            name           = job

            container_properties = jsonencode({
                image   = module.ecr[job].repository_url
                environment = [
                    { 
                        name = "MLFLOW_TRACKING_URI", 
                        value = var.mlflow_tracking_uri
                    }
                ]
                resourceRequirements = [
                    fileexists("${path.root}/../ml-projects/${job}/resource-requirements.json") ? jsondecode(file("${path.root}/../ml-projects/${job}/resource-requirements.json")) : var.default_resource_requirements
                ] # custom resource requirements can be defined in ml-projects/${job}/resource-requirements.json
                logConfiguration = {
                    logDriver = "awslogs"
                    options = {
                        awslogs-group         = "/aws/batch/training-jobs/${job}"
                        awslogs-region        = data.aws_region.current.name
                        awslogs-stream-prefix = "ec2"
                    }
                }
            })
        }
    }
    project_shas = zipmap(
        [
            for job in var.training_jobs : job
        ], 
        [
            for job in var.training_jobs : sha1(join("", [for f in fileset("${path.root}/../ml-projects/${job}", "**") : filesha1("${path.root}/../ml-projects/${job}/${f}")]))
        ]
        # local.input_list
    )
}