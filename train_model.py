import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error, r2_score
import joblib

# Load dataset
df = pd.read_csv("global_air_quality_data_10000.csv")

# Drop non-numeric columns
df = df.drop(columns=["City", "Country", "Date"])

# Create AQI (simple weighted formula)
df["AQI"] = (
    0.4 * df["PM2.5"] +
    0.3 * df["PM10"] +
    0.1 * df["NO2"] +
    0.1 * df["SO2"] +
    0.05 * df["CO"] +
    0.05 * df["O3"]
)

# Features & Target
X = df.drop("AQI", axis=1)
y = df["AQI"]

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

# Train model
model = RandomForestRegressor(
    n_estimators=200,
    random_state=42
)
model.fit(X_train, y_train)

# Evaluation
y_pred = model.predict(X_test)
print("RMSE:", np.sqrt(mean_squared_error(y_test, y_pred)))
print("R2 Score:", r2_score(y_test, y_pred))

# Save model
joblib.dump(model, "aqi_model.pkl")
print("Model saved as aqi_model.pkl")
