import pandas as pd

FEATURES = [
    "lag_24h", "lag_48h", "lag_168h", "mean_7d",
    "hr", "dow", "is_weekend", "is_holiday_nl",
    "temp", "precip", "solarradiation", "windspeed", "cloudcover", "humidity",
    "charger_num", "latitude", "longitude", "perimeter", "area",
]


def preprocess(df: pd.DataFrame) -> pd.DataFrame:
    """The one feature path for train, predict and serving. hr and dow stay plain ints."""
    x = df[FEATURES].copy()
    for c in ("is_weekend", "is_holiday_nl"):
        x[c] = x[c].astype("int8")
    return x.astype("float32")
