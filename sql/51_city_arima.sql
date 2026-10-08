-- 51_city_arima.sql
CREATE OR REPLACE MODEL ev_ds.arima_city
OPTIONS (
  model_type = 'ARIMA_PLUS',
  time_series_timestamp_col = 'ts',
  time_series_data_col = 'y',
  data_frequency = 'HOURLY',
  auto_arima_max_order = 2,
  horizon = 744
) AS
SELECT ts, y FROM ev_ds.city_hourly WHERE ts < TIMESTAMP '2023-07-31 22:00:00+00';

CREATE OR REPLACE TABLE ev_ds.pred_city_arima AS
SELECT forecast_timestamp AS ts,
  TIMESTAMP_DIFF(forecast_timestamp, TIMESTAMP '2023-07-31 22:00:00+00', HOUR) + 1 AS horizon_h,
  forecast_value AS y_hat
FROM ML.FORECAST(MODEL ev_ds.arima_city, STRUCT(744 AS horizon, 0.8 AS confidence_level));
