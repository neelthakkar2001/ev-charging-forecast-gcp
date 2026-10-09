import pandas as pd

from training.preprocess import FEATURES, preprocess


def test_preprocess_columns_and_dtypes():
    row = {c: 1 for c in FEATURES}
    row["is_weekend"], row["is_holiday_nl"] = True, False
    x = preprocess(pd.DataFrame([row]))
    assert list(x.columns) == FEATURES
    assert (x.dtypes == "float32").all()
    assert x.loc[0, "is_weekend"] == 1 and x.loc[0, "is_holiday_nl"] == 0
