.PHONY: help local-training remote-training deployment local-batch-inference remote-batch-inference mlflow-server

DEFAULT_ENV_MANAGER=conda

# variables for local training and deployment
project ?= test-project
register ?= True
inference_input ?= ./other/input-examples/predict_example.csv
inference_output ?= ./predict_output.csv
input_type ?= csv
model ?= test-project/latest

# variables for MLFlow server
build_mlflow_server ?= false

# variables for training pipelines  and deployment infrastructure
SSM_TRAINING_JOB_SET = /$${TF_VAR_project}/$${TF_VAR_region}/$${TF_VAR_env_name}/training-job-set
SSM_DEPLOYMENT_JOB_SET = /$${TF_VAR_project}/$${TF_VAR_region}/$${TF_VAR_env_name}/deployment-job-set
update_action ?= add

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

# build:
# 	echo "Argument 1: $(arg1)"
# 	echo "Argument 2: $(arg2)"

## Re-runs an MLFlow project locally and optionally creates a new version of the model in the MLFlow registry.
## Example usage: make local-training project=test-project.
local-training:
	mlflow run ml-projects/$(project) \
		--experiment-name $(project)

## Deploys the model to a local endpoint in port 5050 using MLFLow. This command is blocking.
## Example usage: make local-deployment model=test-project.
local-deployment:
	mlflow models serve \
		--env-manager=$(DEFAULT_ENV_MANAGER) \
		-m models:/$(model) \
		-p 5050

## Runs a test request to the local endpoint and returns the result.
local-deployment-test:
	curl http://127.0.0.1:5050/invocations -H 'Content-Type:application/json' -d @./other/input-examples/serve_example.json

## Runs a batch inference job locally, using .csv inputs and outputs.
## Example usage: make local-batch-inference model=test-project inference_input=input/path.csv inference_output=output/path.csv.
local-batch-inference:
	mlflow models predict \
		--env-manager=$(DEFAULT_ENV_MANAGER) \
		-t $(input_type) \
		-m models:/$(model) \
		--input-path $(inference_input) \
		--output-path $(inference_output)
	echo "Inference completed. Input : $(inference_input), Output : $(inference_output)"

mlflow-server-switch:
	aws ssm put-parameter \
		--name "/$${TF_VAR_project}/$${TF_VAR_region}/$${TF_VAR_env_name}/build-mlflow-server" \
		--description "This parameter holds the state that terraform uses to decide whether an MLFlow server is built" \
		--value "$(build_mlflow_server)" \
		--type "String" \
		--overwrite

tf-apply:
	cd ./terraform && terraform init \
		-backend-config="bucket=$${TF_VAR_state_bucket_name}" \
		-backend-config="key=$${TF_VAR_project}/$${TF_VAR_env_name}/tf.state" \
		-backend-config="region=$${TF_VAR_region}" \
	&& terraform apply -var-file=terraform.tfvars

# this line sets a default value for the build_mlflow_server variable inside the rule's scope
mlflow-server: build_mlflow_server=true
## Provisions the MLflow server infrastructure
mlflow-server: mlflow-server-switch tf-apply

## Tears down the MLflow server infrastructure
mlflow-server-rm: mlflow-server-switch tf-apply

# Checks that the project folder exists, then updates the SSM parameter set and applies the Terraform configuration
update-ssm-set:
	if [ -d ml-projects/$(project) ]; then \
        python utils/update_ssm_set.py \
		--param=$(ssm_param) \
		--elem=$(project) \
		--action=$(update_action); \
    else \
		echo "Project folder $(project) not found. Please ensure that the project folder exists in ml-projects/."; \
        exit 1; \
    fi
	make tf-apply

# Sets default values for training-job rule
training-job: ssm_param=$(SSM_TRAINING_JOB_SET) update_action=add
## Provisions the training job pipeline infrastructure and launches it. Example use: make training-job project=test-project.
training-job: update-ssm-set tf-apply

# Sets default values for training-job-rm rule
training-job-rm: ssm_param=$(SSM_TRAINING_JOB_SET) update_action=remove
## Tears down the training job pipeline. Example use: make training-job-rm project=test-project.
training-job-rm: update-ssm-set tf-apply

# Sets default values for deployment-job rule
deployment-job: ssm_param=$(SSM_DEPLOYMENT_JOB_SET) update_action=add
## Provisions model deployment infrastructure. Example use: make deployment-job project=test-project.
deployment-job: update-ssm-set tf-apply

# Sets default values for deployment-job-rm rule
deployment-job-rm: ssm_param=$(SSM_DEPLOYMENT_JOB_SET) update_action=remove
## Tears down model deployment infrastructure. Example use: make deployment-job-rm project=test-project.
deployment-job-rm: update-ssm-set tf-apply