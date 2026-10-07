CREATE OR REPLACE TABLE ev_ds.pred_naive_24 AS
SELECT ts, site_id, hr + 1 AS horizon_h, lag_24h AS y_hat
FROM ev_ds.features WHERE split IN ('val', 'test');

CREATE OR REPLACE TABLE ev_ds.pred_naive_168 AS
SELECT ts, site_id, hr + 1 AS horizon_h, lag_168h AS y_hat
FROM ev_ds.features WHERE split IN ('val', 'test');

CREATE OR REPLACE TABLE ev_ds.pred_naive_4wk AS
SELECT ts, site_id, hr + 1 AS horizon_h, mean_4w_same_hour AS y_hat
FROM ev_ds.features WHERE split IN ('val', 'test');
