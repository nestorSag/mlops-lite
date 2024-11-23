.PHONY: help local-training remote-training deployment local-batch-inference remote-batch-inference mlflow-server

DEFAULT_ENV_MANAGER=conda

# variables for local training and deployment
project ?= test-project
register ?= True
inference_input ?= ./other/input-examples/predict_example.csv
inference_output ?= ./predict_output.csv
input_type ?= csv
version ?= latest

# variables for MLFlow server
build_mlflow_server ?= false

# variables in the Parameter Store to track  training pipelines and deployment infrastructure
SSM_TRAINING_JOB_SET = /$${TF_VAR_project}/$${TF_VAR_region}/$${TF_VAR_env_name}/training_jobs
SSM_DEPLOYMENT_JOBS_JSON = /$${TF_VAR_project}/$${TF_VAR_region}/$${TF_VAR_env_name}/deployment_jobs
action ?= add

## Display this help message
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')


## Runs an MLFlow project locally. Example usage: make local-training project=test-project.
local-training:
	MLFLOW_EXPERIMENT_NAME=$(project) mlflow run ml-projects/$(project)

## Deploys the model to a local endpoint in port 5050. Example usage: make local-deployment project=test-project version=1.
local-deployment:
	mlflow models serve \
		--env-manager=$(DEFAULT_ENV_MANAGER) \
		-m models:/$(project)/$(version) \
		-p 5050

# initialises SSM parameters on which Terraform configuration depends
ssm_params:
	python utils/init_ssm_param.py \
		--param=$(SSM_TRAINING_JOB_SET)
	python utils/init_ssm_param.py \
		--param=$(SSM_DEPLOYMENT_JOBS_JSON) \
		--is_json

tf-apply: ssm_params
	cd ./terraform && terraform init \
		-backend-config="bucket=$${TF_VAR_state_bucket_name}" \
		-backend-config="key=$${TF_VAR_project}/$${TF_VAR_env_name}/tf.state" \
		-backend-config="region=$${TF_VAR_region}" \
	&& terraform refresh \
		-target=data.aws_ssm_parameter.training_jobs \
		-target=data.aws_ssm_parameter.deployment_jobs \
	&& terraform apply \
	-var-file=terraform.tfvars 

## Provisions the MLflow server infrastructure
mlflow-server: tf-apply

# Checks that the project folder exists, then updates the SSM parameter set and applies the Terraform configuration
update-ssm-set:
	if [ -d ml-projects/$(project) ]; then \
        python utils/update_ssm_set.py \
		--param=$(ssm_param) \
		--elem=$(project) \
		--action=$(action); \
    else \
		echo "Project folder $(project) not found. Please ensure that the project folder exists in ml-projects/."; \
        exit 1; \
    fi

# Checks that the project folder exists, then updates the SSM JSON string and applies the Terraform configuration
update-ssm-json:
	if [ -d ml-projects/$(project) ]; then \
        python utils/update_ssm_json.py \
		--param=$(ssm_param) \
		--key=$(project) \
		--value=$(version) \
		--action=$(action); \
    else \
		echo "Project folder $(project) not found. Please ensure that the project folder exists in ml-projects/."; \
        exit 1; \
    fi


## Provisions the training job pipeline infrastructure. Example use: make training-job project=test-project.
training-infra:
	make update-ssm-set ssm_param=$(SSM_TRAINING_JOB_SET) action=add project=$(project)
	make tf-apply

## Launches a training job, provisioning the infrastructure if needed. Example use: make training-job project=test-project.
training-job: training-infra
	aws batch submit-job \
	--job-name "$(project)-$$(date +%Y-%m-%d-%H-%M-%S)" \
	--job-queue training_jobs_queue \
	--job-definition "training_job_$(project)"


## Tears down the training job infrastructure. Example use: make training-job-rm project=test-project.
training-infra-rm: 
	make update-ssm-set ssm_param=$(SSM_TRAINING_JOB_SET) action=remove project=$(project)
	make tf-apply

## Provisions model deployment infrastructure. Example use: make deployment project=test-project version=latest.
deployment:
	make update-ssm-json action=add ssm_param=$(SSM_DEPLOYMENT_JOBS_JSON) key=$(project) value=$(version)
	make tf-apply

## Tears down model deployment infrastructure. Example use: make deployment-rm project=test-project.
deployment-rm: 
	make update-ssm-json action=remove ssm_param=$(SSM_DEPLOYMENT_JOBS_JSON) key=$(project)
	make tf-apply

## Starts a process that sends periodic requests to the local endpoint. Usage: make endpoint-test endpoint_name=<name> sample_data=<path>
endpoint-test:
	python utils/test_endpoint.py \
		--endpoint-name=$(endpoint_name) \
		--sample-data=$(sample_data) \
		--region=$${TF_VAR_region}
## Tears down Terraform infrastructure
teardown: 
	cd terraform && python ../utils/delete_batch_compute_env.py \
		--env_name=$$(terraform output compute_env_name) \
		--queue_name=$$(terraform output jobs_queue_name)
	@echo "Waiting for the Batch compute environment to be deleted before continuing..."
	sleep 30
	cd ./terraform && terraform destroy -var-file=terraform.tfvars
	aws ssm delete-parameter --name $(SSM_TRAINING_JOB_SET)
	aws ssm delete-parameter --name $(SSM_DEPLOYMENT_JOBS_JSON)