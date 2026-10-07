CREATE OR REPLACE TABLE ev_ds.pred_arima AS
SELECT
  forecast_timestamp AS ts,
  site_id,
  TIMESTAMP_DIFF(forecast_timestamp, TIMESTAMP '2023-07-31 22:00:00+00', HOUR) + 1 AS horizon_h,
  forecast_value AS y_hat
FROM ML.FORECAST(MODEL ev_ds.arima_site, STRUCT(744 AS horizon, 0.8 AS confidence_level));
