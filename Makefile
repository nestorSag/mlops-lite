.PHONY: help local-training remote-training deployment local-batch-inference remote-batch-inference mlflow-server

project ?= main-project
register ?= True

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

## Re-runs the MLFlow project job locally and creates a new version of the model in the MLFlow registry.
## Example usage: make local-training project=main-project register=True.
local-training:
	mlflow run ./$(project) \
		--experiment-name $(project) \
		-P register=$(register) \
		-P experiment_name=$(project)

## Re-runs the containerised MLFlow project job in AWS and creates a new version of the model in the MLFlow registry.
remote-training:
	echo "Retraining the model remotely"

## Deploys the model to a local endpoint using MLFLow. Pass --model-name and --model-version to specify the model to deploy from the MLFlow registry.
local-deployment:
	echo "Deploying the model"

## Deploys the model to a SageMaker endpoint using MLFLow. Pass --model-name and --model-version to specify the model to deploy from the MLFlow registry.
remote-deployment:
	echo "Deploying the model"

## Runs a batch inference job locally, using .csv inputs and outputs. Pass --model-name and --model-version to specify the model to use from the MLFlow registry.
local-batch-inference:
	echo "Running batch inference locally"

## Runs a batch inference job remotely, using .csv inputs and outputs. Pass --model-name and --model-version to specify the model to use from the MLFlow registry.
remote-batch-inference:
	echo "Running batch inference remotely"

## Bootstraps the MLflow server using the Terraform configuration in tf/
mlflow-server:
	echo "Bootstrapping MLflow server"

## Destroys the MLflow server created with the Terraform configuration in tf/
mlflow-server-rm:
	echo "Bootstrapping MLflow server"

## Starts a monitoring job on a SageMaker endpoint.
monitoring-job:
	echo "Launching montiroing job"