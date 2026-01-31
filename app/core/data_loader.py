import pandas as pd

df = pd.read_csv("data/global_air_quality_data_10000.csv")

df["City"] = df["City"].str.lower().str.strip()
df["Country"] = df["Country"].str.lower().str.strip()
