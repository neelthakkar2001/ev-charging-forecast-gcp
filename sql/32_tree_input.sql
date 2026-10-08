CREATE OR REPLACE TABLE ev_ds.tree_input AS
SELECT
  ts, site_id,
  energy_kwh AS y_raw,
  energy_kwh - lag_24h AS y_resid,
  lag_24h, lag_48h, lag_168h, mean_7d,
  hr, dow, is_weekend, is_holiday_nl,
  temp, precip, solarradiation, windspeed, cloudcover, humidity,
  charger_num, latitude, longitude, perimeter, area,
  CASE WHEN split = 'train' THEN 'TRAIN'
       WHEN ts < TIMESTAMP '2023-08-24 22:00:00+00' THEN 'EVAL'
       ELSE 'TEST' END AS xsplit
FROM ev_ds.features
WHERE split IN ('train', 'val')
  AND lag_24h IS NOT NULL AND lag_168h IS NOT NULL AND mean_7d IS NOT NULL;
