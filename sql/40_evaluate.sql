CREATE OR REPLACE TABLE ev_ds.metrics AS
WITH preds AS (
  SELECT 'naive_24h' AS model, ts, site_id, y_hat FROM ev_ds.pred_naive_24
  UNION ALL SELECT 'naive_168h', ts, site_id, y_hat FROM ev_ds.pred_naive_168
  UNION ALL SELECT 'naive_4wk', ts, site_id, y_hat FROM ev_ds.pred_naive_4wk
  UNION ALL SELECT 'arima_plus', ts, site_id, y_hat FROM ev_ds.pred_arima
),
buckets AS (
  SELECT * FROM UNNEST([
    STRUCT('day1' AS bucket, 1 AS max_day),
    STRUCT('wk1' AS bucket, 7 AS max_day),
    STRUCT('all' AS bucket, 999 AS max_day)])
),
j AS (
  SELECT p.model, f.split, p.site_id, f.ts, f.energy_kwh AS y, p.y_hat,
         DIV(TIMESTAMP_DIFF(f.ts,
               IF(f.split = 'val', TIMESTAMP '2023-07-31 22:00:00+00', TIMESTAMP '2023-08-31 22:00:00+00'),
               HOUR), 24) + 1 AS day_idx
  FROM preds p
  JOIN ev_ds.features f ON f.ts = p.ts AND f.site_id = p.site_id
  WHERE f.split IN ('val', 'test')
),
jb AS (SELECT j.*, b.bucket FROM j JOIN buckets b ON j.day_idx <= b.max_day),
site AS (
  SELECT model, split, bucket,
         SAFE_DIVIDE(SUM(ABS(y - y_hat)), SUM(y)) AS wape_site,
         AVG(ABS(y - y_hat)) AS mae,
         SQRT(AVG(POW(y - y_hat, 2))) AS rmse,
         COUNT(*) AS n_rows,
         COUNTIF(y_hat IS NULL) AS n_null_pred
  FROM jb
  GROUP BY model, split, bucket
),
per_site AS (
  SELECT model, split, bucket, site_id, SAFE_DIVIDE(SUM(ABS(y - y_hat)), SUM(y)) AS w
  FROM jb
  GROUP BY model, split, bucket, site_id
),
med AS (
  SELECT model, split, bucket, APPROX_QUANTILES(w, 100)[OFFSET(50)] AS wape_site_median
  FROM per_site
  GROUP BY model, split, bucket
),
city AS (
  SELECT model, split, bucket, SAFE_DIVIDE(SUM(ABS(y - y_hat)), SUM(y)) AS wape_city
  FROM (
    SELECT model, split, bucket, ts, SUM(y) AS y, SUM(y_hat) AS y_hat
    FROM jb
    GROUP BY model, split, bucket, ts
  )
  GROUP BY model, split, bucket
)
SELECT * FROM site JOIN city USING (model, split, bucket) JOIN med USING (model, split, bucket);
