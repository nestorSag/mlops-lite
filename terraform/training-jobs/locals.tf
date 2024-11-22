locals {
    log_group_name = "/aws/batch/training-jobs"
    project_shas = zipmap(
        [
            for job in var.training_jobs : job
        ], 
        [
            for job in var.training_jobs : sha1(join("", [for f in fileset("${path.root}/../ml-projects/${job}", "**") : filesha1("${path.root}/../ml-projects/${job}/${f}")]))
        ]
        # map of the form { job_name -> sha1_hash_of_files_in_mlproject_directory }
    )
    user_provided_resource_requirements = {
        for job in var.training_jobs : job => fileexists("${path.root}/../config/${job}/training-resource-requirements.json") ? jsondecode(file("${path.root}/../config/${job}/training-resource-requirements.json")) : null
    }
    resource_requirements = {
        for job in var.training_jobs : job => local.user_provided_resource_requirements[job] != null ? local.user_provided_resource_requirements[job] : var.default_training_resource_requirements
    }
    job_definitions = {
        for job in var.training_jobs : job => {
            name           = "training_job_${job}"

            platform_capabilities = ["FARGATE"]

            container_properties = jsonencode({
                image   = "${module.ecr[job].repository_url}:${local.project_shas[job]}"
                fargatePlatformConfiguration = {
                    platformVersion = "LATEST"
                },
                environment = [
                    { 
                        name = "MLFLOW_TRACKING_URI", 
                        value = var.mlflow_tracking_uri
                    },
                    { 
                        name = "MLFLOW_EXPERIMENT_NAME", 
                        value = job
                    }
                ]
                # custom resource requirements can be defined in ml-projects/${job}/training-resource-requirements.json
                resourceRequirements = local.resource_requirements[job]
                logConfiguration = {
                    logDriver = "awslogs"
                    options = {
                        awslogs-group         = local.log_group_name
                        awslogs-region        = data.aws_region.current.name
                        awslogs-stream-prefix = "${job}"
                    }
                }
                jobRoleArn = aws_iam_role.instance_role.arn
                executionRoleArn = aws_iam_role.task_execution_role.arn
            })
        }
    }
}