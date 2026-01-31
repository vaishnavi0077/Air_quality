from fastapi import FastAPI
from app.routers import aqi

app = FastAPI(title="AQI Prediction API")

app.include_router(aqi.router)

@app.get("/health")
def health():
    return {"status": "API running"}

