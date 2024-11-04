

module "ecr" {
  for_each = local.training_jobs
  source = "git::github.com/terraform-aws-modules/terraform-aws-ecr?ref=841b3c7"

  repository_name = each.key
  repository_image_tag_mutability = "IMMUTABLE"
  repository_force_delete = true

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 2 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 2
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

}

resource "null_resource" "bundle_build_and_push_mlproject_image" {
  for_each = local.training_jobs
  provisioner "local-exec" {
    command = <<-EOT
    cd ${path.root}/..
    mkdir -p tmp
    cp Makefile tmp/
	cp -r ./ml-projects/${each.key} tmp/${each.key}
	cp ./other/docker/mlproject-template/Dockerfile tmp/Dockerfile

    aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${module.ecr[each.key].repository_url}
    docker build \
      --platform=linux/amd64 \
      -t ${module.ecr[each.key].repository_url}:${self.project_sha} \
      "${path.module}/docker"
    docker push ${module.ecr[each.key].repository_url}:${self.project_sha}
    EOT
  }

  triggers = {
    # Rebuild the image if any of the files in the mlproject directory change
    project_sha = sha1(join("", [for f in fileset("${path.root}/../each.key", ["**"]) : filesha1("${path.root}/../${each.key}/${f}")]))
  }
}


module "batch" {
  source = "git::github.com/terraform-aws-modules/terraform-aws-batch?ref=c478369"

  compute_environments = {
    fargate_compute_env = {
      name_prefix = "fargate"

      compute_resources = {
        type      = "FARGATE"

        security_group_ids = [module.vpc_endpoint_security_group.security_group_id]
        subnets            = var.compute_env_subnet_ids

      }
    }
  }

  # Job queus and scheduling policies
  job_queues = {
    low_priority = {
      name     = "training-jobs"
      state    = "ENABLED"
      priority = 1

      compute_environments = ["fargate_compute_env"]

      tags = {
        JobQueue = "Training jobs queue"
      }
    }
  }

  job_definitions = local.job_definitions
}