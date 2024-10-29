.PHONY: help local-training remote-training deployment local-batch-inference remote-batch-inference mlflow-server

DEFAULT_ENV_MANAGER=conda

project ?= test-project
register ?= True
inference_input ?= ./other/input-examples/predict_example.csv
inference_output ?= ./predict_output.csv
input_type ?= csv
model ?= test-project/latest


build_mlflow_server ?= false

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
## Example usage: make local-training project=test-project register=True.
local-training:
	mlflow run ml-projects/$(project) \
		--experiment-name $(project) \
		-P register=$(register) \
		-P experiment_name=$(project)

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
mlflow-server-create: build_mlflow_server=true
## Creates the MLflow server using the Terraform configuration in tf/
mlflow-server-create: mlflow-server-switch tf-apply

## Destroys the MLflow server using the Terraform configuration in tf/
mlflow-server-destroy: mlflow-server-switch tf-apply

## Re-runs the containerised MLFlow project job in AWS and creates a new version of the model in the MLFlow registry.
remote-training:
	echo "Retraining the model remotely"

## Deploys the model to a SageMaker endpoint using MLFLow. Pass --model-name and --model-version to specify the model to deploy from the MLFlow registry.
remote-deployment:
	echo "Deploying the model"

## Runs a batch inference job remotely, using .csv inputs and outputs. Pass --model-name and --model-version to specify the model to use from the MLFlow registry.
remote-batch-inference:
	echo "Running batch inference remotely"
## Destroys the MLflow server created with the Terraform configuration in tf/
mlflow-server-rm:
	echo "Bootstrapping MLflow server"