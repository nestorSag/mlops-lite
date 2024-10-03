
from data import load_data
from preproc import preproc_data
from train import train_model
from evaluate import evaluate_model

import mlflow
from sklearn.model_selection import train_test_split
import numpy as np

np.random.seed(42)

if __name__ == "__main__":
    X, y = load_data()
    X = preproc_data(X)
    X_train, X_test, y_train, y_test = train_test_split(X, y)
    mlflow.autolog(log_input_examples=True)
    with mlflow.start_run():
        model = train_model(X_train, y_train)
        evaluate_model(model, X_test, y_test)
    