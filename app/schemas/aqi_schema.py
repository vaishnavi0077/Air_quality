from pydantic import BaseModel

class CityCountryInput(BaseModel):
    city: str
    country: str

