locals {
    job_definitions = {
        for job in var.training_jobs : job => {
            name           = "training_job_${job}"

            platform_capabilities = ["FARGATE"]

            container_properties = jsonencode({
                image   = module.ecr[job].repository_url
                fargatePlatformConfiguration = {
                    platformVersion = "LATEST"
                },
                environment = [
                    { 
                        name = "MLFLOW_TRACKING_URI", 
                        value = var.mlflow_tracking_uri
                    }
                ]
                # custom resource requirements can be defined in ml-projects/${job}/resource-requirements.json
                resourceRequirements = fileexists("${path.root}/../ml-projects/${job}/resource-requirements.json") ? jsondecode(file("${path.root}/../ml-projects/${job}/resource-requirements.json")) : var.default_resource_requirements
                logConfiguration = {
                    logDriver = "awslogs"
                    options = {
                        awslogs-group         = "/aws/batch/training-jobs/${job}"
                        awslogs-region        = data.aws_region.current.name
                        awslogs-stream-prefix = "ec2"
                    }
                }
                jobRoleArn = aws_iam_role.instance_role.arn
                executionRoleArn = aws_iam_role.task_execution_role.arn
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
        # map of the form { job_name -> sha1_hash_of_files_in_mlproject_directory }
    )
}