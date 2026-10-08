CREATE OR REPLACE TABLE ev_ds.metrics_city AS
WITH preds AS (
  SELECT 'arima_city' AS model, ts, y_hat FROM ev_ds.pred_city_arima
  UNION ALL SELECT 'xreg_city', ts, y_hat FROM ev_ds.pred_city_xreg
  UNION ALL SELECT 'arima_city', ts, y_hat FROM ev_ds.pred_city_arima_t
  UNION ALL SELECT 'xreg_city', ts, y_hat FROM ev_ds.pred_city_xreg_t
  UNION ALL SELECT 'site_arima_summed', ts, SUM(y_hat) FROM ev_ds.pred_arima GROUP BY ts
  UNION ALL SELECT 'naive_24h', ts, SUM(y_hat) FROM ev_ds.pred_naive_24 GROUP BY ts
  UNION ALL SELECT 'bt_raw', ts, SUM(y_hat) FROM ev_ds.pred_bt_raw GROUP BY ts
  UNION ALL SELECT 'bt_resid', ts, SUM(y_hat) FROM ev_ds.pred_bt_resid GROUP BY ts
),
buckets AS (
  SELECT * FROM UNNEST([
    STRUCT('day1' AS bucket, 1 AS max_day),
    STRUCT('wk1' AS bucket, 7 AS max_day),
    STRUCT('all' AS bucket, 999 AS max_day)])
),
j AS (
  SELECT p.model,
         IF(c.ts < TIMESTAMP '2023-08-31 22:00:00+00', 'val', 'test') AS split,
         DIV(TIMESTAMP_DIFF(c.ts,
               IF(c.ts < TIMESTAMP '2023-08-31 22:00:00+00',
                  TIMESTAMP '2023-07-31 22:00:00+00', TIMESTAMP '2023-08-31 22:00:00+00'),
               HOUR), 24) + 1 AS day_idx,
         c.y, p.y_hat
  FROM preds p JOIN ev_ds.city_hourly c USING (ts)
  WHERE c.ts >= TIMESTAMP '2023-07-31 22:00:00+00'
)
SELECT model, split, b.bucket,
  SAFE_DIVIDE(SUM(ABS(y - y_hat)), SUM(y)) AS wape_city,
  AVG(ABS(y - y_hat)) AS mae,
  SQRT(AVG(POW(y - y_hat, 2))) AS rmse,
  COUNT(*) AS n_rows
FROM j JOIN buckets b ON j.day_idx <= b.max_day
GROUP BY model, split, b.bucket;
