"""XGBoost on the residual label. Reads ev_ds.tree_input, writes val predictions to BQ,
the model and result.json to GCS, and params/metrics to Vertex Experiments."""
import argparse
import json
import os
import tempfile

import numpy as np
import pandas as pd
import xgboost as xgb
from google.cloud import aiplatform, bigquery, storage

from preprocess import preprocess

# best bt_resid trial (docs/results.md): depth 4, learn rate 0.231
PARAMS = dict(max_depth=4, learning_rate=0.231, n_estimators=500, objective="reg:absoluteerror",
              tree_method="hist", early_stopping_rounds=30, eval_metric="mae", random_state=0)
LOCATION = "us-central1"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--project", required=True)
    p.add_argument("--bucket", required=True)
    p.add_argument("--run-id", required=True)
    p.add_argument("--dataset", default="ev_ds")
    p.add_argument("--experiment", default="ev-demand")
    p.add_argument("--site-mod", type=int, default=1, help="keep 1 site in N (smoke test); 1 = all")
    a = p.parse_args()

    ds = f"`{a.project}.{a.dataset}"
    bq = bigquery.Client(project=a.project, default_query_job_config=bigquery.QueryJobConfig(
        maximum_bytes_billed=3_000_000_000))
    pick = f"MOD(ABS(FARM_FINGERPRINT(CAST(site_id AS STRING))), {a.site_mod}) = 0"

    tr = bq.query(f"SELECT * FROM {ds}.tree_input` WHERE {pick}").to_dataframe()
    t, e, h = (tr[tr.xsplit == s] for s in ("TRAIN", "EVAL", "TEST"))
    y = lambda d: d.y_resid.astype("float32")  # noqa: E731
    m = xgb.XGBRegressor(**PARAMS)
    m.fit(preprocess(t), y(t), eval_set=[(preprocess(e), y(e))], verbose=50)
    eval_mae = float(m.best_score)
    inner_test_mae = float(np.mean(np.abs(y(h) - m.predict(preprocess(h)))))

    v = bq.query(f"SELECT * FROM {ds}.features` WHERE split = 'val' AND {pick}").to_dataframe()
    actual = v.energy_kwh.astype(float)
    y_hat = np.maximum(0.0, v.lag_24h.astype(float) + m.predict(preprocess(v)))
    val_wape = float(np.abs(actual - y_hat).sum() / actual.sum())
    out = pd.DataFrame({"ts": v.ts, "site_id": v.site_id, "horizon_h": v.hr + 1, "y_hat": y_hat})
    bq.load_table_from_dataframe(
        out, f"{a.project}.{a.dataset}.pred_xgb_resid",
        job_config=bigquery.LoadJobConfig(write_disposition="WRITE_TRUNCATE")).result()

    # keep only the trees up to the best iteration, so a plain Booster.predict at serving agrees
    model_path = os.path.join(tempfile.gettempdir(), "model.bst")
    m.get_booster()[: m.best_iteration + 1].save_model(model_path)
    base = f"runs/{a.run_id}"
    bkt = storage.Client(project=a.project).bucket(a.bucket)
    bkt.blob(f"{base}/model/model.bst").upload_from_filename(model_path)
    res = dict(run_id=a.run_id, val_wape=val_wape, eval_mae=eval_mae, inner_test_mae=inner_test_mae,
               best_iteration=int(m.best_iteration), n_train=len(t), n_val=len(v),
               model_uri=f"gs://{a.bucket}/{base}/model")
    bkt.blob(f"{base}/result.json").upload_from_string(json.dumps(res))
    print(res)

    if a.site_mod == 1:  # smoke runs stay out of Experiments
        aiplatform.init(project=a.project, location=LOCATION, experiment=a.experiment)
        aiplatform.start_run(a.run_id)
        aiplatform.log_params({k: str(v_) for k, v_ in PARAMS.items()})
        aiplatform.log_metrics({k: res[k] for k in ("val_wape", "eval_mae", "inner_test_mae", "best_iteration")})
        aiplatform.end_run()


if __name__ == "__main__":
    main()
