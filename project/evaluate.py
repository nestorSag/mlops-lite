from sklearn.model_selection import train_test_split
import mlflow
from sklearn.metrics import r2_score, mean_absolute_error

def evaluate_model(
    model,
    X_true,
    y_true,
):
    y_pred = model.predict(X_true)
    r2 = r2_score(y_true, y_pred)
    mae = mean_absolute_error(y_true, y_pred)
    mlflow.log_metric("r2", r2)
    mlflow.log_metric("mae", mae)
