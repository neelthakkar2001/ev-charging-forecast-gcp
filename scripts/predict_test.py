import sys

import numpy as np
import pandas as pd
import xgboost as xgb
from google.cloud import bigquery, storage

sys.path.insert(0, "training")
from preprocess import preprocess  # noqa: E402

project, bucket, run_id = sys.argv[1:4]
storage.Client(project=project).bucket(bucket).blob(f"runs/{run_id}/model/model.bst").download_to_filename("model.bst")
m = xgb.Booster()
m.load_model("model.bst")
bq = bigquery.Client(project=project, default_query_job_config=bigquery.QueryJobConfig(maximum_bytes_billed=3_000_000_000))
v = bq.query(f"SELECT * FROM `{project}.ev_ds.features` WHERE split = 'test'").to_dataframe()
x = preprocess(v)
y_hat = np.maximum(0.0, v.lag_24h.astype(float) + m.predict(xgb.DMatrix(x)))
out = pd.DataFrame({"ts": v.ts, "site_id": v.site_id, "horizon_h": v.hr + 1, "y_hat": y_hat})
bq.load_table_from_dataframe(out, f"{project}.ev_ds.pred_xgb_resid",
                             job_config=bigquery.LoadJobConfig(write_disposition="WRITE_APPEND")).result()
print(len(out))
