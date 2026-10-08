CREATE OR REPLACE MODEL ev_ds.bt_resid
TRANSFORM(
  y_resid,
  lag_24h, lag_48h, lag_168h, mean_7d,
  CAST(hr AS STRING) AS hr,
  CAST(dow AS STRING) AS dow,
  is_weekend, is_holiday_nl,
  temp, ML.QUANTILE_BUCKETIZE(temp, 8) OVER () AS temp_bucket,
  precip, solarradiation, windspeed, cloudcover, humidity,
  charger_num, latitude, longitude, perimeter, area,
  xsplit
)
OPTIONS (
  model_type = 'BOOSTED_TREE_REGRESSOR',
  input_label_cols = ['y_resid'],
  data_split_method = 'CUSTOM',
  data_split_col = 'xsplit',
  num_trials = 10,
  max_parallel_trials = 3,
  hparam_tuning_objectives = ['MEAN_ABSOLUTE_ERROR'],
  max_tree_depth = HPARAM_RANGE(4, 8),
  learn_rate = HPARAM_RANGE(0.02, 0.3),
  enable_global_explain = TRUE,
  model_registry = 'VERTEX_AI',
  vertex_ai_model_id = 'ev_demand_bt_resid'
) AS
SELECT * FROM ev_ds.tree_input;
