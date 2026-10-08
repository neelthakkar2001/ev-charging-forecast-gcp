-- Vertex serves the bare XGBoost model: TRANSFORM is not applied there, and ts / site_id are
-- rejected as non-features. ML.TRANSFORM applies the model's own stored TRANSFORM (same
-- bucket boundaries as training). y_raw and xsplit are dummies the TRANSFORM needs as inputs;
-- they are dropped again. No key is left: compare with pred_bt_raw on (latitude, longitude, hr).
CREATE OR REPLACE TABLE ev_ds.batch_input AS
SELECT * EXCEPT (y_raw, xsplit)
FROM ML.TRANSFORM(MODEL ev_ds.bt_raw, (
  SELECT
    energy_kwh AS y_raw, 'TEST' AS xsplit,
    lag_24h, lag_48h, lag_168h, mean_7d, hr, dow, is_weekend, is_holiday_nl,
    temp, precip, solarradiation, windspeed, cloudcover, humidity,
    charger_num, latitude, longitude, perimeter, area
  FROM ev_ds.features
  WHERE ts >= TIMESTAMP '2023-07-31 22:00:00+00' AND ts < TIMESTAMP '2023-08-01 22:00:00+00'));
