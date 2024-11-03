

from data import load_data
from preproc import preproc_data
from train import train_model
from evaluate import evaluate_model
import os

import mlflow
from sklearn.model_selection import train_test_split
import numpy as np

np.random.seed(42)

if __name__ == "__main__":
    # Load data
    X, y = load_data()
    # Preprocess data
    X = preproc_data(X)
    X_train, X_test, y_train, y_test = train_test_split(X, y)
    with mlflow.start_run():
        # get experiment name
        # mlflow.active_run().info.experiment_id
        experiment_name = os.getenv("MLFLOW_EXPERIMENT_NAME")
        # Train model
        model = train_model(X_train, y_train)
        # Evaluate model
        evaluate_model(model, X_test, y_test)
        mlflow.sklearn.log_model(
            model, 
            artifact_path = "model", 
            registered_model_name=experiment_name,
            input_example=X_train.head(1)
        )