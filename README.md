# Lean MLOps control centre with MLFlow + AWS + Terraform

This project allows you to manage the life cycle of your ML projects easily: train, track, deploy, monitor or retire your models with a single command. 

It uses MLFlow to track and containerise models, AWS services to productionise them, and Terraform to keep track of the infrastructure.

# Scope

It should work out of the box for models that can be trained in a single EC2 instance (up to a few hundred GBs of RAM usage, depending on instance type).

# Requirements

* GNU `make`

* Python 3

* Terraform 

* AWS CLI

* Docker (without `sudo`)

* Appropriate AWS permissions

# Workflow

## MLFlow provisioning

This project uses [this Terraform module](https://github.com/nestorSag/terraform-aws-mlflow-server) to provision a production MLFlow server. Run `make mlflow-server` to start the process. The server architecture is shown below.

![Architecture diagram](other/images/mlflow-server.png)

This server will register and containerise any models added to this platform. You can also use it as an experiment tracking platform.
The UI is accessible through a VPN, which is created and managed by Terraform as part of the platform. See the [repo](https://github.com/nestorSag/terraform-aws-mlflow-server) for access instructions.

## Integrating a new model

Add a new subfolder in the `ml-projects` folder sticking to the following constraints:

* Folders should be structured as valid [MLFlow projects](https://mlflow.org/docs/latest/projects.html).

* They should have an `MLProject` file specifying entry points and environment managers. Both `conda` and `venv` environment managers are supported.

* They should be runnable with `mlflow run` without passing any additional `-P` arguments; set defaults as needed.

* Your `MLProject` code is responsible for fetching the data (e.g. from S3), training the model and logging it to MLFlow along with any other artifacts; you can assume `MLFLOW_TRACKING_URI` will point to the provisioned server automatically. See the example included. Note even jupyter notebooks are fine, as long as they log the model as a valid [MLFlow Model](https://mlflow.org/docs/latest/models.html); this is straightforward to do for most ML libraries using the `mlflow` client library.

## Launching (re)training jobs

run `make training-job project=<my-project>`, where `my-project` is a subfolder in `ml-projects`. This will use Terraform to

1. Containerise your MLProject

2. Create an ECR for your container

3. Create AWS Batch compute environments in Fargate, along with a queue and task definitions.

Your training job will be launched on top of the above infrastructure. The end result is a new registered model in your MLFlow Registry (which your MLProject is assumed to handle internally, see [Integrating a new model](#integrating-a-new-model)), with name `<my-project>`. The MLFlow tracking URI is propagated automatically, do not hardcode it.

![Architecture diagram](other/images/training-jobs.png)

### Specifying computational requirements

You can create a `resource-requirements.json` file in `config/<my-project>/` with the following format to specify the computational requirements of your training job:

```json
[
    {"type": "VCPU", "value": "2"},
    {"type": "MEMORY", "value": "4096"},
    {"type": "GPU", "value": "1"}
]
```

The GPU line is optional, and you can remove it if your model does not use GPUs. If this file is not found, default values will be used. You must set your own defaults in Terraform variable `default_training_resource_requirements`.

### Permissions for training containers

You can specify custom IAM policies for your training containers in `config/global/training-jobs-policy.json`. If the file is not found, a default policy is used, which allows containers to

* Read and write to any S3 bucket

* Read Parameter Store values with preffix `${var.project}/${var.region}/${var.env_name}`.  

* Read Secrets Store values with preffix `${var.project}/${var.region}/${var.env_name}`.

Note the same IAM policies are used for all ML projects.

### Passing environment variables to training containers

`MLFLOW_TRACKING_URI` is the only environment variable passed to the batch job container when launched. If your container needs additional values, these will have to be fetched from the AWS Parameter Store or Secrets Store internally.

### Tearing down training job infrastructure

Training job infrastructure for a specific project can be tear down with `make training-job-rm project=<my-project>`

## Launching deployment jobs 

run `make deployment-job project=<my-project> version=<my-version>`, where `my-project` is a subfolder in `ml-projects` and `<my-version>` is an available model version in the MLFlow Registry under the `<my-project>` name. This will use Terraform and MLFlow to

1. Continerise a specific model from the MLFlow Registry

2. Create an AWS SageMaker endpoint where the model is to be deployed

3. Create CloudWatch dashboards to track endpoint metrics, as well as model and data metrics.

### Endpoint and deployment configuration

You can create files `./config/<project>/endpoint.config` and `./config/<project>/deployment.config` to specify endpoint and deployment configuration for each project. Note they should mirror the resource structure for [`sagemaker_endpoint_configuration`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sagemaker_endpoint_configuration) and `sagemaker_endpoint`'s [DeploymentConfig](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sagemaker_endpoint) respectively.

Both blue-green and rollout deployments are supported, but not all other parameters are. See the defaults included in this project at `./terraform/defaults.tf` to get an idea of supported parameter blocks. By default, the endpoints are serverless and use a blue-green deployment strategy.


### Data capture and async inference

Data capture and async inference are enabled and managed by default, and results are stored at buckt `s3://<TF_VAR_project>-<TF_VAR_envname>-sagemaker-endpoint-store` and folders `data_capture` and `async_inference` respectively. You can change data capture configuration in `./terraform/defaults.tf`.

### Deployment image

The deployment image is the one provided by default by MLFlow

## Model monitoring


## Endpoint decomissioning


### Specifying SageMaker endpoint configuration

You can add a `resource-requirements.json` file in `ml-projects/<my-project>` with the following format to specify the computational requirements of your training job:

```json
[
    {"type": "VCPU", "value": "2"},
    {"type": "MEMORY", "value": "4096"},
    {"type": "GPU", "value": "1"}
]
```

The GPU line is optional, and you can remove it if your model does not use GPUs. If this file is not found, default values are used. You can set your own defaults with Terraform's `default_training_resource_requirements` variable.

### Tearing down deployment job infrastructure

Deployment job infrastructure for a specific project can be tear down with `make deployment-job-rm project=<my-project>`

## Model rollouts and rollbacks

Both model updates and rollbacks are handled by simply deploying a different model version under an existing endpoint.


# Life cycle management with GitHub actions

Every step of the workflow above can be performed by manually launching GitHub action workflows. This has the advantage of preventing uncommited code leaks into your model life cycle, and setting clear permissions boundaries for who can launch what kind of job.

# Getting started

Whether your launch environment is your local machine or GitHub Actions, you will need to

1. Define the following environment variables

```sh
export TF_VAR_state_bucket_name=<my-bucket>
export TF_VAR_region=<my-region>
export TF_VAR_project=<my-project>
export TF_VAR_env_name=<my-env>
```

`TF_VAR_state_bucket_name` holds the S3 bucket with the global Terraform state. This is needed for GitHub Actions to work, and also if multiple people can launch jobs. In the latter case, it is recommended to set a Terraform state lock table as well.

2. Set up a Python virtual environment and install the `requirements.txt` file

3. Make sure your AWS CLI is configured appropriately

4. Mofidy file `./terraform/terraform.tfvars` and set appropriate values for your project.

5. As long as you have the necessary AWS permissions, you can provision the MLFlow server at this point running `make mlflow-server`.

6. Review the default permissions and configuration at `./terraform/defaults.tf` before training or deploying any model.

6. If you need to access the UI, [set up the server's VPN locally](https://github.com/nestorSag/terraform-aws-mlflow-server).

7. You are ready to go 🚀 you can use the `test-project` subfolder in this repository to try provisioning training and deployment pipelines.

8. Add model-specific configuration at `./config/<ml-project>` to control permissions, hardware resources and endpoint configurations for individual ML projects.

⚠️ Keep in mind this project requires broad permissions across multiple services such as ECS, S3, VPC, Batch, RDS, SageMaker, among others.

⚠️ This project uses billable services.


# Notes

* At this time, The support for the MLFlow server's metadata DB is limited to MySQL 8.0

* This project does not implement shadow or blue/green deployment at this time.