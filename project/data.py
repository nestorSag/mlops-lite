from sklearn.datasets import fetch_california_housing
import pandas as pd

def load_data():
    dataset = fetch_california_housing()
    X = pd.DataFrame(dataset.data, columns=dataset.feature_names)
    y = pd.Series(dataset.target)
    return X, y