CREATE OR REPLACE MODEL ev_ds.arima_site
OPTIONS (
  model_type = 'ARIMA_PLUS',
  time_series_timestamp_col = 'ts',
  time_series_data_col = 'energy_kwh',
  time_series_id_col = 'site_id',
  data_frequency = 'HOURLY',
  holiday_region = 'NL',
  auto_arima_max_order = 2,
  horizon = 744
) AS
SELECT ts, site_id, energy_kwh FROM ev_ds.features WHERE split = 'train';
