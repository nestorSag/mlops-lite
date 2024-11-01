
import argparse
import sys

from data import load_data
from preproc import preproc_data
from train import train_model
from evaluate import evaluate_model

import mlflow
from sklearn.model_selection import train_test_split
import numpy as np

np.random.seed(42)

if __name__ == "__main__":
    # Parse command line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--register", type=str)
    parser.add_argument("--experiment_name", type=str)
    args = parser.parse_args()
    # Load data
    X, y = load_data()
    # Preprocess data
    X = preproc_data(X)
    X_train, X_test, y_train, y_test = train_test_split(X, y)
    mlflow.autolog(log_input_examples=True)
    with mlflow.start_run(experiment_id=args.experiment_name):
        # Train model
        model = train_model(X_train, y_train)
        # Evaluate model
        evaluate_model(model, X_test, y_test)
        if args.register.lower() == "true":
            run_id = mlflow.active_run().info.run_id
            mlflow.register_model(f"runs:/{run_id}/model", args.experiment_name)
    