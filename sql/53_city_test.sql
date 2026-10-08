-- Phase F3: city pair on the test month. Same as 51 / 52, retrained on Apr-Aug,
-- 720 h forecast from 2023-08-31 22:00 UTC (= September 2023 local).
CREATE OR REPLACE MODEL ev_ds.arima_city_t
OPTIONS (
  model_type = 'ARIMA_PLUS',
  time_series_timestamp_col = 'ts',
  time_series_data_col = 'y',
  data_frequency = 'HOURLY',
  auto_arima_max_order = 2,
  horizon = 720
) AS
SELECT ts, y FROM ev_ds.city_hourly WHERE ts < TIMESTAMP '2023-08-31 22:00:00+00';

CREATE OR REPLACE TABLE ev_ds.pred_city_arima_t AS
SELECT forecast_timestamp AS ts,
  TIMESTAMP_DIFF(forecast_timestamp, TIMESTAMP '2023-08-31 22:00:00+00', HOUR) + 1 AS horizon_h,
  forecast_value AS y_hat
FROM ML.FORECAST(MODEL ev_ds.arima_city_t, STRUCT(720 AS horizon, 0.8 AS confidence_level));

CREATE OR REPLACE MODEL ev_ds.xreg_city_t
OPTIONS (
  model_type = 'ARIMA_PLUS_XREG',
  time_series_timestamp_col = 'ts',
  time_series_data_col = 'y',
  data_frequency = 'HOURLY',
  auto_arima_max_order = 2,
  horizon = 720
) AS
SELECT ts, y, temp, precip, solarradiation, windspeed, cloudcover, humidity
FROM ev_ds.city_hourly WHERE ts < TIMESTAMP '2023-08-31 22:00:00+00';

CREATE OR REPLACE TABLE ev_ds.pred_city_xreg_t AS
SELECT forecast_timestamp AS ts,
  TIMESTAMP_DIFF(forecast_timestamp, TIMESTAMP '2023-08-31 22:00:00+00', HOUR) + 1 AS horizon_h,
  forecast_value AS y_hat
FROM ML.FORECAST(MODEL ev_ds.xreg_city_t, STRUCT(720 AS horizon, 0.8 AS confidence_level),
  (SELECT ts, temp, precip, solarradiation, windspeed, cloudcover, humidity
   FROM ev_ds.city_hourly
   WHERE ts >= TIMESTAMP '2023-08-31 22:00:00+00' AND ts < TIMESTAMP '2023-09-30 22:00:00+00'));
