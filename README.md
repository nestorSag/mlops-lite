# MLOps control centre with Terraform + MLFlow + AWS

This project is intended to provide a lean MLOps control centre to train, track, deploy, monitor and retire ML models using MLFlow and Terraform on AWS.

# Scope

It should work out of the box for models that can be trained in a single EC2 instance (up to a few hundred GBs of RAM usage, depending on instance type). 

# Requirements

* GNU `make`

* Python 3

* Terraform 

* AWS CLI

* Docker (`sudo`-less)

* Appropriate AWS permissions

# Workflow

## MLFlow provisioning (optional)

This project uses [this Terraform module](https://github.com/nestorSag/terraform-aws-mlflow-server) to provision a production MLFlow server if one is needed. Run `make mlflow-server` to start the process, or `make mlflow-server-rm` to tear it down. The server architecture is shown below.

![Architecture diagram](other/images/mlflow-server.png)


If you have an existing MLFlow server you can skip this step, but you will have to set `MLFLOW_TRACKING_URI` to your tracking URI.

## Adding a new model

Add a new subfolder in the `ml-projects` folder with the following constraints:

* Models should be packaged as valid [MLFlow projects](https://mlflow.org/docs/latest/projects.html).

* They should have an `MLProject` file specifying entry points and environment managers. 

* They should be runnable with `mlflow run` without passing any additional arguments (set defaults as needed). Both `conda` and `venv` environment managers are supported.

* The `MLProject` code is responsible for fetching the data, training the model and logging it to MLFlow along with its metrics. See the example included. Note even jupyter notebooks are fine, as long as it does the latter.

## Launching training jobs

run `make training-job project=<my-project>`, where `my-project` is a subfolder in `ml-projects`. This will use Terraform to

1. Containerise your MLProject

2. Create an ECR for your container

3. Create AWS Batch compute environments, queue and task definitions if necessary.

Your training job will be launched on top of the above infrastructure. The end result is a new registered model in your MLFlow Registry (which your MLProject is assumed to handle internally), with name `<my-project>`. The MLFlow tracking URI is propagated automatically, do not hardcode it.

![Architecture diagram](other/images/training-jobs.png)

You can configure Terraform variables with an email list that gets notified whenever a job fails or succeeds.

### Specifying computational requirements

You can add a `resource-requirements.json` file in `ml-projects/<my-project>` with the following format to specify the computational requirements of your training job:

```json
[
    {"type": "VCPU", "value": "2"},
    {"type": "MEMORY", "value": "4096"},
    {"type": "GPU", "value": "1"}
]
```

The GPU line is optional, and you can remove it if your model does not use GPUs. If this file is not found, default values are used. You can set your own defaults with Terraform's `default_resource_requirements` variable.

### Tearing down training job infrastructure

Training job infrastructure for a specific project can be tear down with `make training-job-rm project=<my-project>`

## Launching deployment jobs 

run `make deployment-job project=<my-project> model=<my-version>`, where `my-project` is a subfolder in `ml-projects` and `<my-version>` is an available model version in the MLFlow Registry under the `<my-project>` experiment. This will use Terraform to

1. Continerise a specific model from the MLFlow Registry

2. Create an AWS SageMaker endpoint where the model is to be deployed

3. Create CloudWatch dashboards to track endpoint metrics, as well as model and data metrics.

### Specifying SageMaker endpoint configuration

You can add a `resource-requirements.json` file in `ml-projects/<my-project>` with the following format to specify the computational requirements of your training job:

```json
[
    {"type": "VCPU", "value": "2"},
    {"type": "MEMORY", "value": "4096"},
    {"type": "GPU", "value": "1"}
]
```

The GPU line is optional, and you can remove it if your model does not use GPUs. If this file is not found, default values are used. You can set your own defaults with Terraform's `default_resource_requirements` variable.

### Tearing down deployment job infrastructure

Deployment job infrastructure for a specific project can be tear down with `make deployment-job-rm project=<my-project>`

## Model updates and rollbacks

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

2. Decide whether to provision an MLFlow server or bring your own. If you bring your own, in addition to the above you need to define

```sh
export MLFLOW_TRACKING_URI=<my-uri>
```

If you provision it, make sure to select appropriate values for the server and DB parameters. This will depend on your expected server load.

3. If a VPN is needed to reach your MLFlow server (that is the case if you provision it with this project; the VPN and its credentials are provisioned along with the server), make sure to pass the VPN credentials to GitHub Actions or your local environment.

4. Set your Terraform variables through `terraform.tfvars` file or in some other way.

5. Make sure that your local environment and/or GitHub actions have appropriate credentials. Keep in mind this project uses many AWS services such as S3, ECR, Batch, SageMaker, Parameter Store, and others.

6. You are ready to go 🚀 you can use the `test-project` subfolder in this repository to warm up.