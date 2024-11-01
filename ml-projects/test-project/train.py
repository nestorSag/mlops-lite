from sklearn.ensemble import GradientBoostingRegressor

from data import load_data
from preproc import preproc_data

def train_model(X, y):
    model = GradientBoostingRegressor()
    model.fit(X, y)
    return model