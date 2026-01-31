from fastapi import APIRouter, HTTPException
import numpy as np
import pandas as pd
from app.schemas.aqi_schema import CityCountryInput
from app.core.data_loader import df
from app.core.model_loader import model

router = APIRouter(
    prefix="/api/v1/aqi",
    tags=["AQI"]
)

# 🔹 Temporary in-memory storage (for latest result)
latest_prediction = {}

def aqi_category(aqi):
    if aqi <= 50:
        return "Good"
    elif aqi <= 100:
        return "Moderate"
    elif aqi <= 200:
        return "Poor"
    else:
        return "Very Poor"

# ✅ POST API – prediction
@router.post("/predict")
def predict_aqi(data: CityCountryInput):
    city = data.city.lower().strip()
    country = data.country.lower().strip()

    rows = df[(df["City"] == city) & (df["Country"] == country)]

    if rows.empty:
        raise HTTPException(status_code=404, detail="City & country not found")

    rows["Date"] = pd.to_datetime(rows["Date"])
    row = rows.sort_values("Date", ascending=False).iloc[0]

    features = np.array([[
        row["PM2.5"],
        row["PM10"],
        row["NO2"],
        row["SO2"],
        row["CO"],
        row["O3"],
        row["Temperature"],
        row["Humidity"],
        row["Wind Speed"]
    ]])

    aqi = model.predict(features)[0]
    status = aqi_category(aqi)

    global latest_prediction
    latest_prediction = {
        "city": data.city,
        "country": data.country,
        "aqi": round(aqi, 2),
        "status": status
    }

    return latest_prediction


# ✅ GET API – frontend fetches this
@router.get("/latest")
def get_latest_aqi():
    if not latest_prediction:
        raise HTTPException(status_code=404, detail="No prediction available yet")

    return latest_prediction

