CREATE OR REPLACE TABLE ev_ds.pred_bt_raw AS
SELECT ts, site_id, hr + 1 AS horizon_h, GREATEST(0, predicted_y_raw) AS y_hat
FROM ML.PREDICT(MODEL ev_ds.bt_raw,
  (SELECT * FROM ev_ds.features WHERE split = 'val'));

CREATE OR REPLACE TABLE ev_ds.pred_bt_resid AS
SELECT ts, site_id, hr + 1 AS horizon_h, GREATEST(0, lag_24h + predicted_y_resid) AS y_hat
FROM ML.PREDICT(MODEL ev_ds.bt_resid,
  (SELECT * FROM ev_ds.features WHERE split = 'val'));
