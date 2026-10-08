INSERT INTO ev_ds.pred_bt_raw (ts, site_id, horizon_h, y_hat)
SELECT ts, site_id, hr + 1, GREATEST(0, predicted_y_raw)
FROM ML.PREDICT(MODEL ev_ds.bt_raw,
  (SELECT * FROM ev_ds.features WHERE split = 'test'));

INSERT INTO ev_ds.pred_bt_resid (ts, site_id, horizon_h, y_hat)
SELECT ts, site_id, hr + 1, GREATEST(0, lag_24h + predicted_y_resid)
FROM ML.PREDICT(MODEL ev_ds.bt_resid,
  (SELECT * FROM ev_ds.features WHERE split = 'test'));
