# Case study: day-ahead EV charging forecast on GCP

**In short.** I built a day-ahead, hourly demand forecast for 1,388 Amsterdam charging sites on BigQuery ML and Vertex AI, with a quality gate that only registers a model if it beats a simple baseline. The best model, XGBoost, **tied** the baseline "same hour yesterday" (September test WAPE 0.0078 vs 0.0080), and the gate correctly blocked it on the validation month. I treat that as the result: the project shows how to build, test, gate and tear down an ML workflow honestly, including what did not work.

## 1. Problem and decision it supports

Charging operators and grid planners need tomorrow's load by hour. Too little capacity means queues and grid stress, too much means wasted cost. The forecast is issued at midnight for the next 24 hours, per site, so every input is at least 24 hours old. A model is only useful if it beats what a planner could do for free: look at yesterday.

## 2. Data and a leakage-safe split

Source: the CHARGED dataset, Amsterdam subset, April to September 2023, 6,096,096 site-hour rows plus hourly weather. The split is by time: training to July, August for validation, September for test. No random split, because it leaks the future into training. Features use lags of 24 hours or more only. The September data was kept out of every training query and **scored once**, after tagging the code (`freeze-day4`). If a bug is found after seeing test, the numbers must be marked as contaminated, not quietly fixed.

Data problems I found and documented rather than hid: the `volume` column is probably not literal kWh (it fails a sanity check), source timestamps are local Amsterdam time (confirmed from solar radiation peaking at 13:00) and were converted to UTC. Because of the unit problem, WAPE is the headline metric.

## 3. Baselines and metric

WAPE (sum of absolute errors over sum of actuals). The bar is `naive_24h`: the value from the same hour yesterday. It is very hard to beat, with 1.3% WAPE on validation and 0.8% on test. The series look smoothed (31% of training site-hours repeat the previous hour exactly, lag-24 correlation 0.979), so yesterday is almost the answer.

## 4. Model comparison

| Model | Val WAPE | Test WAPE |
|---|---|---|
| `xgb_resid` | 0.0135 | 0.0078 |
| `naive_24h` | 0.0133 | 0.0080 |
| `bt_resid` (BQML tree) | 0.0208 | 0.0161 |
| `bt_raw` (BQML tree) | 0.0900 | 0.1293 |

- **Raw trees lose.** `bt_raw` spends its capacity re-learning "same as yesterday" and ends up worse than a weekly naive.
- **The residual label fixes most of it.** Predicting `energy_kwh - lag_24h` and adding `lag_24h` back cut test error from 0.1293 to 0.0161.
- **XGBoost on the residual ties the baseline.** It kept a single tree, because every extra tree made the validation score worse, which suggests what is left is mostly noise.
- **Weather did not help.** On the city series, a model with six weather regressors was worse than plain `ARIMA_PLUS`, and `ML.GLOBAL_EXPLAIN` ranked weather low. That is with actual weather as the forecast, so it is an upper bound.

The 0.0002 gap goes opposite ways on the two months and was not tested for significance, so the safe description is a tie.

## 5. GCP architecture and why

BigQuery ML first, because SQL features, baselines, tuning and explainability are cheap and fast there. Vertex AI for what BigQuery does not give you: a model registry, batch inference, custom training in your own container, experiment tracking and a gated pipeline. The training image is custom because the prebuilt training images were past their end-of-availability date. Everything runs on CPU, in `us-central1` and the US multi-region, so BigQuery and Vertex stay in matching regions.

## 6. MLOps: gate, registry, CI

The pipeline is `train -> evaluate -> gate -> register only if the gate passes`. `evaluate` recomputes validation WAPE from BigQuery and cross-checks the container's own number. `gate` compares it live with `naive_24h` and writes every decision to a table.

- **Honest run:** candidate 0.013498 vs baseline 0.013332, so **block**, and nothing is registered.
- **Forced run:** the threshold is overridden to 0.05 only to prove that the register branch works. The model is labelled `gate=forced` and is a demo, not a promotion. Vertex's step cache reused the earlier train step, so only `register` ran.

CI on GitHub Actions authenticates with Workload Identity Federation: no stored keys, limited to this repository by its numeric id (a repository name can be taken over, an id cannot), as a read-only service account. It dry-runs the SQL and runs the unit tests, and never submits a pipeline.

**What is not proven.** One `preprocess()` function is the single feature path for training and scoring, but **serving is not proven**: the registered XGBoost model returns the residual, and a live prediction test failed because the saved model remembers feature names while the serving container sends none. So the model is registered, not served. The same kind of train/serve mismatch also appeared with the BigQuery ML tree, whose `TRANSFORM` is not applied when Vertex serves it. A serving test is the first thing I would add.

## 7. How this maps to other platforms

The lifecycle here (train, evaluate, gate, register, CI) is the standard ML delivery loop. On GCP it looks like this: features are SQL-first in BigQuery, tracking is Vertex Experiments, the registry and pipeline are managed services, and the CI login is keyless through Workload Identity Federation. The same loop exists on other platforms under other names, for example MLflow tracking and registry, Databricks Workflows or Azure ML pipelines.

## 8. Next steps

- Use weather forecasts instead of actuals as covariates.
- Fix serving: save the booster without feature names, add `lag_24h` back outside the model, and add a serving test to CI.
- Add Model Monitoring (drift, skew) for the live feature path.
- Test whether the 0.0002 gap is real, with a bootstrap over days on the validation month, not by re-reading September.

*Limitations that frame all of the above: six summer months in one city, oracle weather, smoothed data with unclear units, and tuning on August (so validation is optimistic). The data are not redistributed because the source licences conflict.*
