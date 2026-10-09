# Results so far (val = Aug 2023 local, test = Sep 2023 local)

**Headline (Day 3): neither boosted tree beats `naive_24h`.** On the September test, site WAPE is 0.0080 for `naive_24h`, 0.0161 for `bt_resid` and 0.1293 for `bt_raw`; val gives the same ranking (0.0133, 0.0208, 0.0900). The series look smoothed (31% of train site-hours repeat the previous hour exactly, lag-24 correlation 0.979), so yesterday is almost the answer and a tree has to spend capacity re-learning it. Predicting the residual on `lag_24h` (`bt_resid`) removes most of that cost but does not beat the baseline. Weather did not help either: on the city series the weather model is worse than plain ARIMA on both val and test (oracle weather, so an upper bound).

**Day 4 update: XGBoost on the residual label ties `naive_24h`.** Val 0.0135 vs 0.0133 (the gate blocked it), September test 0.0078 vs 0.0080 (read once). The gap is 0.0002 either way, and the city-level test scores are equal at 0.0014, so it is a tie within what we can measure, not a win. Details, the blocked and forced pipeline runs and the freeze note are in "Day 4" at the end of this file.

Gate baseline (lowest val WAPE, bucket all): naive_24h, WAPE 0.0133. Day 4's pipeline gate must beat this (the better of `naive_24h` 0.0133 and the best tree, `bt_resid` 0.0208, is still `naive_24h`).

| model | split | bucket | WAPE site-pooled | WAPE city | MAE | RMSE | n_rows |
|---|---|---|---|---|---|---|---|
| naive_24h | val | all | 0.0133 | 0.0056 | 0.438 | 2.423 | 1,032,672 |
| naive_168h | val | all | 0.0538 | 0.0220 | 1.766 | 7.253 | 1,032,672 |
| arima_plus | val | all | 0.1114 | 0.0942 | 3.656 | 6.630 | 1,032,672 |
| naive_4wk | val | all | 0.1422 | 0.0659 | 4.667 | 17.070 | 1,032,672 |
| naive_24h | val | wk1 | 0.0186 | 0.0110 | 0.606 | 2.297 | 233,184 |
| arima_plus | val | wk1 | 0.1037 | 0.0997 | 3.384 | 6.051 | 233,184 |
| naive_168h | val | wk1 | 0.1134 | 0.0795 | 3.703 | 8.522 | 233,184 |
| naive_4wk | val | wk1 | 0.2312 | 0.1515 | 7.546 | 19.267 | 233,184 |
| naive_24h | val | day1 | 0.0699 | 0.0614 | 2.267 | 4.438 | 33,312 |
| arima_plus | val | day1 | 0.1000 | 0.0969 | 3.246 | 5.902 | 33,312 |
| naive_168h | val | day1 | 0.1273 | 0.0950 | 4.131 | 8.767 | 33,312 |
| naive_4wk | val | day1 | 0.3246 | 0.2499 | 10.533 | 22.176 | 33,312 |
| naive_24h | test | all | 0.0080 | 0.0014 | 0.264 | 1.304 | 999,360 |
| naive_168h | test | all | 0.0318 | 0.0028 | 1.050 | 6.432 | 999,360 |
| naive_4wk | test | all | 0.0723 | 0.0047 | 2.390 | 15.834 | 999,360 |
| naive_24h | test | wk1 | 0.0087 | 0.0020 | 0.287 | 1.490 | 233,184 |
| naive_168h | test | wk1 | 0.0318 | 0.0033 | 1.049 | 6.425 | 233,184 |
| naive_4wk | test | wk1 | 0.0726 | 0.0036 | 2.393 | 15.847 | 233,184 |
| naive_24h | test | day1 | 0.0086 | 0.0018 | 0.281 | 1.476 | 33,312 |
| naive_168h | test | day1 | 0.0312 | 0.0032 | 1.025 | 6.404 | 33,312 |
| naive_4wk | test | day1 | 0.0716 | 0.0044 | 2.356 | 15.822 | 33,312 |

Notes:
- naive_* are rolling day-ahead (every input is at least 24 h old). arima_plus is one 744 h forecast from 2023-07-31 22:00 UTC, trained on Apr-Jul only. The day1, wk1 and all buckets cover the same target hours for every model, but the models do not get the same information.
- arima_plus is scored on val only. Its test run (retrained through 31 Aug) is Day 3. Its val WAPE being worse than naive_24h is not a verdict between them.
- WAPE = sum of absolute errors divided by sum of actuals. Site-pooled sums over all site-hours; city sums predictions and actuals per hour first.
- `energy_kwh` is probably not literal kWh (see data-notes.md), so MAE and RMSE are in unverified units. WAPE is the headline.
- naive_24h WAPE is very low (1.3% val, 0.8% test). EDA found 31% of train site-hours repeat the previous hour exactly, so the series look smoothed. A day-ahead model has to beat a hard baseline.
- Oracle weather: the weather features are actuals, not forecasts. Any weather uplift is an upper bound.
- Test numbers for the fitted models are in the Day 3 table below.

## Day 3 final: site-level models, val and test

WAPE site-pooled. Trees are scored on val and on the September test; `arima_plus` was not rerun on test (cut by plan).

| model | val all | test all | val day1 | test day1 | test MAE, all |
|---|---|---|---|---|---|
| naive_24h (gate) | 0.0133 | 0.0080 | 0.0699 | 0.0086 | 0.264 |
| bt_resid | 0.0208 | 0.0161 | 0.0661 | 0.0168 | 0.534 |
| naive_168h | 0.0538 | 0.0318 | 0.1273 | 0.0312 | 1.050 |
| naive_4wk | 0.1422 | 0.0723 | 0.3246 | 0.0716 | 2.390 |
| bt_raw | 0.0900 | 0.1293 | 0.1006 | 0.0971 | 4.276 |
| arima_plus | 0.1114 | not scored | 0.1000 | not scored | n/a |

- Test number of rows: 999,360 for bucket `all`, 0 null predictions. Test ranking: naive_24h < bt_resid < naive_168h < naive_4wk < bt_raw.
- `bt_resid` loses to `naive_24h` in every bucket on test (about twice the error), and wins only on val `day1` (0.0661 vs 0.0699). `bt_raw` is the worst model on test (RMSE 58.9: a few very large misses), even worse than `naive_4wk`.
- The trees were tuned on August data (EVAL and the inner TEST holdout), so their val numbers are optimistic. The test month is the honest number, and nothing was changed after the test numbers were produced. Test was not better for the trees than val in relative terms: `bt_resid` / `naive_24h` is 1.6 on val and 2.0 on test.
- Trees are day-ahead (every lag at least 24 h old, oracle weather). `arima_plus` is one frozen-origin 744 h forecast. They do not get the same information.
- Units: `energy_kwh` is probably not literal kWh, so MAE and RMSE are in unverified units. WAPE is the headline.
- Feature importance: `lag_24h` dominates (see "bt_raw global explain" below). Batch inference through Vertex did not match `ML.PREDICT` (see "Batch inference").

## Doc checks

- **CUSTOM split with tuning:** `data_split_col` must be a STRING column. `TRAIN` rows train, `EVAL` rows evaluate, `TEST` rows test. Without tuning it is a BOOL column instead (FALSE = train, TRUE/NULL = eval). The split column is excluded from the features automatically. Source: CREATE MODEL boosted-tree page, read 2026-10-08. Only seen via page summary, not verbatim.
- **Is TEST required?** Not stated in the docs. `NUM_TRIALS` triggers a 3-way split (hp-tuning-overview). For non-CUSTOM methods an empty test set is allowed and the eval set is reused as test. Whether that holds for CUSTOM is undocumented. `tree_input` has TEST rows (233,184), so the question does not arise here.
- **Split column outside TRANSFORM?** Not documented. TRANSFORM + CUSTOM combination is also unaddressed. Settled empirically in step B2. Result: `xsplit` must be listed in the TRANSFORM output (error without it: `Missing 'xsplit' column in TRANSFORM clause, which is specified as DATA_SPLIT_COL in input options`). With `xsplit` listed, the model trains and `bq show --model` does not list `xsplit` as a feature.

## bt_raw tuning (Day 3, phase B)

- 10 trials, 3 in parallel, objective MEAN_ABSOLUTE_ERROR, ranges `max_tree_depth` 4-8 and `learn_rate` 0.02-0.3. All 10 trials succeeded. Read with `ML.TRIAL_INFO` and `--nouse_cache` (a cached result from the earlier 1-trial model showed one trial).
- Best trial: 9, `learn_rate` 0.278, `max_tree_depth` 8, MAE 2.869 on the EVAL split (1-24 Aug).

| trial | learn_rate | max_tree_depth | MAE (EVAL) |
|---|---|---|---|
| 9 (best) | 0.278 | 8 | 2.869 |
| 4 | 0.300 | 8 | 2.952 |
| 10 | 0.269 | 8 | 2.976 |
| 7 | 0.241 | 8 | 2.986 |
| 5 | 0.224 | 7 | 3.026 |
| 8 | 0.272 | 7 | 3.102 |
| 2 | 0.239 | 6 | 3.135 |
| 1 | 0.300 | 6 | 3.218 |
| 6 | 0.140 | 8 | 3.518 |
| 3 | 0.172 | 5 | 3.585 |

- **Limitation:** the best trials sit at the edge of the search range. Trial 9 uses the maximum depth (8), the top four trials are depth 7 or 8, and the best learn rates (0.24-0.30) are close to the upper bound 0.3. Deeper trees or a higher learn rate might do better. Not re-tuned, by plan.
- The trial MAE is on August data that the tuning also saw, so it is optimistic. The honest number is the test month in phase F. MAE units are unverified (see data-notes.md).

## bt_raw global explain (Day 3, step C2)

`ML.GLOBAL_EXPLAIN(MODEL ev_ds.bt_raw)`, trial 9 (the best trial). Top 8 of 20 features:

| rank | feature | attribution |
|---|---|---|
| 1 | lag_24h | 27.41 |
| 2 | mean_7d | 3.39 |
| 3 | charger_num | 2.53 |
| 4 | lag_48h | 1.00 |
| 5 | perimeter | 0.83 |
| 6 | latitude | 0.67 |
| 7 | dow | 0.57 |
| 8 | humidity | 0.48 |

- `lag_24h` carries about 7 times the importance of the next feature. The tree mostly re-learns "same as yesterday", which is why `naive_24h` is hard to beat and why the residual model `bt_resid` exists.
- Weather is weak: `humidity` ranks 8th, `temp` 10th, `precip` and `solarradiation` are near zero. This is with oracle weather, so any weather uplift is small even as an upper bound.
- `charger_num`, `perimeter` and `latitude` rank high. There is no `site_id`, so these site statics act as proxies for site size and identity.
- `hr` ranks low (0.04) because `lag_24h` already encodes the hour of day.
- `xsplit`, `ts`, `site_id` and `y_resid` do not appear, so the split column is not used as a feature.

## Boosted trees on val (Day 3, step C4)

- The val numbers for `bt_raw` and `bt_resid` are on data the tuning already saw (EVAL and the inner TEST holdout both come from August), so they are optimistic; the honest number is the September test in phase F.
- **Headline (val):** neither tree beats `naive_24h` over the full month (WAPE site 0.0133). `bt_resid` is the better tree (0.0208). It wins only on `day1` site WAPE (0.0661 vs 0.0699) and on city `wk1` (0.0098 vs 0.0110). Likely reason: the series look smoothed (31% repeated hours, 0.979 lag-24 correlation), so the baseline is almost the answer. Move this paragraph to the top of the file when the final tables are written (step G1).
- **Stop-loss row 4 triggered for `bt_raw`:** val WAPE 0.0900 is worse than `naive_168h` (0.0538). Checked for a bug first. None found: the val MAE (2.954) matches the tuning EVAL MAE (2.869), and for `bt_resid` 0.684 vs 0.727, so the join, the clip at 0 and the lag columns agree with training. The raw tree is just bad at re-learning "same as yesterday" (RMSE 31.7: a few large misses).

| model | WAPE site, all | WAPE site, day1 | WAPE city, all | MAE, all |
|---|---|---|---|---|
| naive_24h | 0.0133 | 0.0699 | 0.0056 | 0.438 |
| bt_resid | 0.0208 | 0.0661 | 0.0075 | 0.684 |
| naive_168h | 0.0538 | 0.1273 | 0.0220 | 1.766 |
| bt_raw | 0.0900 | 0.1006 | 0.0436 | 2.954 |
| arima_plus | 0.1114 | 0.1000 | 0.0942 | 3.656 |
| naive_4wk | 0.1422 | 0.3246 | 0.0659 | 4.667 |

`bt_resid` tuning (10 trials, 3 in parallel, objective MAE on EVAL; label `y_resid`, prediction = `lag_24h` + output, clipped at 0). All 10 trials succeeded.

| trial | learn_rate | max_tree_depth | MAE (EVAL) |
|---|---|---|---|
| 9 (best) | 0.231 | 4 | 0.727 |
| 4 | 0.190 | 4 | 0.740 |
| 8 | 0.183 | 5 | 0.742 |
| 10 | 0.220 | 5 | 0.750 |
| 7 | 0.173 | 4 | 0.755 |
| 6 | 0.106 | 4 | 0.777 |
| 2 | 0.238 | 6 | 0.817 |
| 3 | 0.171 | 7 | 0.826 |
| 5 | 0.233 | 8 | 0.879 |
| 1 | 0.300 | 6 | 0.889 |

- **Limitation:** for `bt_resid` the best trials sit at the **lower** edge of the depth range (best depth 4 is the minimum; the top five are depth 4 or 5). Shallower trees might do better. For `bt_raw` the best sat at the upper edge. Not re-tuned, by plan.

## Batch inference (Day 3, phase D): cut, result does not match ML.PREDICT

One-day slice (1 Aug local, 33,312 rows) of `ev_demand_bt_raw`, Vertex batch prediction on one `n1-standard-2`. **Not usable for scoring.** The batch output disagrees with `ML.PREDICT` and the cause is not found. Cut under the plan's 40 min rule, moved to Day 4.

- **Works:** `outputUri` = `bq://<project>.ev_ds` is accepted. The job writes a table `predictions_<timestamp>` (plus an `_errors` table) into that dataset. The output has the input columns plus a STRING column `prediction` (cast it to FLOAT64). With `instanceType = object` and a BigQuery source the rows are sent by column name.
- **Attempt 1 failed on every row, but the job state said `SUCCEEDED`.** Only `completionStats.failedCount = 33312` and the `_errors` table showed it. Check the counts, not the state. Cause: the registered model is the bare XGBoost. `TRANSFORM` is **not** applied at serving (`ML.PREDICT` applies it, the Vertex path does not), so the input needs the already transformed features (`temp_bucket`, and `hr` / `dow` as strings). `ts` and `site_id` are rejected as non-features (error: `Row 0 has different features ... than the model features`).
- **Fix for attempt 2:** `sql/60_batch_input.sql` builds the input with `ML.TRANSFORM(MODEL ev_ds.bt_raw, ...)`, which applies the model's own stored TRANSFORM (same bucket boundaries as training), then drops `ts`, `site_id` and the dummy `y_raw` / `xsplit`. All 33,312 rows were scored. With no key left, the compare joins on `(latitude, longitude, hr)`, unique here (33,312 of 33,312).
- **Result vs `ML.PREDICT` on the same rows:** max abs diff 126.0, mean abs diff 3.95, correlation 0.98. MAE against actuals: batch 7.02, `ML.PREDICT` 3.27 (matches the `day1` MAE of `bt_raw` in `ev_ds.metrics`, 3.266). So the batch model is a worse, correlated predictor.
- **Cause not found.** Leads, none confirmed: the registry holds a single version (4, alias `default`) created 2m23s after the final `bt_raw` job started, before training finished, so it may not hold the final weights. Or the categorical `hr`, `dow` and `temp_bucket` strings are encoded differently in the serving container. A possible test for Day 4: re-register with `ALTER MODEL ev_ds.bt_raw SET OPTIONS (vertex_ai_model_id = 'ev_demand_bt_raw')` and re-run the batch.
- Cost: about $0.04 per attempt (20 min on one `n1-standard-2`), see `docs/cost-log.md`.
- Day 4 follow-up: lead (1) is closed as untestable and the re-register step is impossible (see "Phase Q" in the Day 4 section at the end).

## Weather uplift (city series), Day 3 phase E

One series (city total per hour, 4,392 rows), `ARIMA_PLUS` vs `ARIMA_PLUS_XREG` with 6 weather regressors (temp, precip, solarradiation, windspeed, cloudcover, humidity). Same training window (Apr-Jul), `auto_arima_max_order = 2`, horizon 744 from 2023-07-31 22:00 UTC. Scored on city WAPE only (`ev_ds.metrics_city`), val only so far.

| model | WAPE city, all | WAPE city, wk1 | WAPE city, day1 |
|---|---|---|---|
| arima_city | 0.1016 | 0.0967 | 0.0911 |
| xreg_city | 0.1122 | 0.1308 | 0.0909 |
| site_arima_summed (Day 2 site model, summed) | 0.0942 | 0.0997 | 0.0969 |
| naive_24h (rolling day-ahead, reference only) | 0.0056 | 0.0110 | 0.0614 |

- **Verdict: weather did not help.** The weather model is slightly worse than the plain one over the month (0.1122 vs 0.1016), clearly worse on the first week (0.1308 vs 0.0967) and equal on day 1. This is with oracle weather (actuals, not forecasts), so a real forecast-weather pipeline would be no better. It agrees with `ML.GLOBAL_EXPLAIN`, where weather features carry almost no importance.
- Both models are frozen-origin 744 h forecasts, not day-ahead, so `naive_24h` (rolling, every input at least 24 h old) is not the right comparison. Its row is shown only for scale. Neither model sets `holiday_region`, so the pair is comparable with each other, not with the site-level model.
- Caveats: one series, one run, order limit 2. The XREG model has more parameters and a long horizon, so a worse WAPE is plausible even without a real weather effect. Not tuned further.
- The test-month pair is phase F3 (below).

### City models on the test month (phase F3, read once)

Both ARIMA models retrained on Apr-Aug, 720 h forecast from 2023-08-31 22:00 UTC (September 2023 local). Trees are scored on the same hours (city totals of their site predictions). City WAPE, test:

| model | all | wk1 | day1 |
|---|---|---|---|
| naive_24h | 0.0014 | 0.0020 | 0.0018 |
| bt_resid | 0.0058 | 0.0063 | 0.0033 |
| bt_raw | 0.0874 | 0.0696 | 0.0654 |
| arima_city | 0.1110 | 0.0264 | 0.0047 |
| xreg_city | 0.1277 | 0.1482 | 0.0394 |

- **Weather did not help on test either.** `xreg_city` is worse than `arima_city` in every bucket (0.1277 vs 0.1110 for the month, 0.1482 vs 0.0264 for the first week, 0.0394 vs 0.0047 for day 1). Val gave the same direction. With oracle weather this is an upper bound for any weather uplift.
- At the city level `naive_24h` still wins on test, and `bt_resid` is a clear second (0.0058). `bt_raw` is far behind (0.0874).
- The frozen-origin ARIMA error grows with the horizon (0.0047 on day 1, 0.1110 over the month). That is a horizon effect, not a day-ahead comparison.

## Day 4: XGBoost custom job, gated pipeline, September scored once

**Headline: `xgb_resid` ties `naive_24h`.** On August (val) it is slightly worse, 0.0135 vs 0.0133 (about 1.2% relative). On September (test, read once) it is slightly better, 0.0078 vs 0.0080 (about 2.5% relative, MAE 0.259 vs 0.264). City-level WAPE is equal on test (0.0014). I did not test whether a 0.0002 gap is more than noise, so this is a tie, not a win. The pipeline gate blocked the model on val, using a rule fixed before test was read, and the better test number does not change that decision.

### Model and runs

- Model: XGBoost 2.1.4 on the residual label (`y_resid = energy_kwh - lag_24h`, prediction = `lag_24h` + output, clipped at 0). `max_depth` 4, `learning_rate` 0.231 (the best `bt_resid` trial), up to 500 trees, `reg:absoluteerror`, early stopping 30 on MAE, `tree_method` hist, `random_state` 0. The 19 `FEATURES` go through one shared function, `preprocess()`, with `hr` and `dow` as plain numbers (no TRANSFORM).
- Container: `python:3.12-slim`, image `us-central1-docker.pkg.dev/ev-forecast-2026/ev/xgb-train:v1`, Vertex CustomJob on `e2-standard-8` as `ev-pipeline-sa`, timeout 90 min.
- Run `c3` (CustomJob 3380177890887860224): 61 s, `n_train` 3,798,956, `n_val` 1,032,672, `eval_mae` 0.4879, `inner_test_mae` 0.2890, `val_wape` 0.013498, **`best_iteration` 0** (only one tree kept). Logged to Experiments `ev-demand` (screenshots `docs/img/day4-experiments-c3-params.png` and `...-metrics.png`).
- The smoke test on 1 site in 20 also stopped at `best_iteration` 1: eval MAE was best after the first tree (0.258) and rose to 0.420 by tree 31. Likely reading: the residual around `lag_24h` is mostly noise a tree cannot learn, so extra trees overfit. I did not test this further. The smoke `val_wape` of 0.0100 is on a subset of sites and is not comparable with the full-data number.
- Two earlier CustomJobs (`c1`, `c2`) failed on missing roles, see "Corrections" below. `c1` and `c2` never wrote results.

### Leaderboard (WAPE site-pooled, bucket all)

| model | val | test | test MAE |
|---|---|---|---|
| xgb_resid | 0.0135 | 0.0078 | 0.259 |
| naive_24h (gate) | 0.0133 | 0.0080 | 0.264 |
| bt_resid | 0.0208 | 0.0161 | 0.534 |
| naive_168h | 0.0538 | 0.0318 | 1.050 |
| naive_4wk | 0.1422 | 0.0723 | 2.390 |
| bt_raw | 0.0900 | 0.1293 | 4.276 |

- Rows: val 1,032,672 and test 999,360 per model, 0 null predictions. The Day 3 numbers did not change when `ev_ds.metrics` was rebuilt.
- Test was scored once with `scripts/predict_test.py` from the frozen `gs://ev-forecast-2026-raw/runs/p1/model/model.bst`, appended to `ev_ds.pred_xgb_resid`. Nothing was changed after seeing it.

### Gated pipeline (`pipelines/pipeline.py`, kfp 2.17.0, google-cloud-pipeline-components 2.22.0)

`train (CustomTrainingJobOp) -> evaluate -> gate -> register only if the gate passes`. `evaluate` recomputes val WAPE from BigQuery (asserts 1,032,672 rows and 0 nulls, and checks it against the container's `result.json` to 1e-6). `gate` reads the `naive_24h` val WAPE live from `ev_ds.metrics` and writes every decision to `ev_ds.gate_log`.

| run | pipeline job | candidate | threshold | forced | decision | registered |
|---|---|---|---|---|---|---|
| honest | ev-xgb-gate-20261009194602 | 0.013498 | 0.013332 (naive_24h) | false | **block** | nothing |
| forced | ev-xgb-gate-20261009221617 | 0.013498 | 0.05 (override) | true | pass | `ev_demand_xgb_resid_forced_demo`, label `gate=forced` |

- **The forced run overrides the gate to prove the register branch works. It is not a win and the registered model is a demo.** Its train, evaluate and gate steps came from the Vertex cache.
- `Model.upload` accepted the artifact folder and the prebuilt `xgboost-cpu.2-1` serving image. **Nothing has served a prediction from it**, so whether the image loads `model.bst` and what it returns is untested. The registered model would return the residual, not the demand.
- The forced run created two identical registry entries. The newer duplicate (8026373859869458432) was deleted, leaving 9130881668482072576. Cause not confirmed: the forced pipeline may have been submitted twice.

### Phase Q: batch mismatch (Day 3 leftover)

- Re-registering is impossible: `ALTER MODEL ev_ds.bt_raw SET OPTIONS (vertex_ai_model_id = ...)` fails with "already registered to Vertex AI". The registry holds exactly one version, `@4`, so a re-run of the batch could only hit it again. Not re-run.
- Lead (1), stale version: `@4` was created 2026-10-08 12:34:35Z, 2.4 minutes after tuning started (12:32:11Z) and about 65 minutes before the BigQuery model finished (13:39:37Z). The BigQuery model records `vertexAiModelVersion: "4"`, so the link is right, but timestamps cannot show whether its weights are the final trial 9. The registry exposes no artifact URI. Untestable.
- Lead (2), encoding: the model's `transformColumns` show `hr` and `dow` become strings and `temp_bucket` comes from `ML.QUANTILE_BUCKETIZE(temp, 8) OVER ()`, which exists only inside the TRANSFORM. The registered model is an XGBoost 0.9 booster.
- The grouped comparison (batch vs `ML.PREDICT` by `hr`, `dow` and `temp` decile) was **not run**. Outcome: **limitation, version @4 weights unverifiable and the cause not isolated.** This is why the XGBoost model takes its preprocessing from `preprocess()` instead of a TRANSFORM.

### Freeze

- Git tag `freeze-day4` was pushed before `sql/40_evaluate.sql` (with the `xgb_resid` line) and `scripts/predict_test.py` were committed. The model, training code, preprocessing and pipeline are in the tag, and the frozen artifact is `runs/p1/model/model.bst`. The two later files only score the model and do not change it.

### CI

- `tests/test_sql_dry_run.py` dry-runs six SQL files (`05_verify_load`, `06_eda`, `15_check_features`, `32_tree_input`, `40_evaluate`, `50_city_series`) and `tests/test_preprocess.py` checks column order and dtypes. 7 tests pass locally under my own credentials.
- `.github/workflows/ci.yml` authenticates through Workload Identity Federation as `ev-ci-sa` (repository id condition). **Not verified:** a green GitHub Actions run. Dry-running `CREATE OR REPLACE TABLE` as `ev-ci-sa` (read-only roles) may need an extra permission.

### Corrections found while executing the plan

- `scikit-learn` was missing from the install list, and `pip` installs into the global Python (this venv is a uv venv).
- `train_xgb.py` saved the model to `/tmp`, which does not exist on Windows.
- `python:3.11-slim` cannot install `numpy==2.5.3` (needs Python 3.12 or newer), so the Dockerfile uses `python:3.12-slim`.
- A3 (role bindings) was not applied before the first CustomJob. Dataset-level `bq add-iam-policy-binding` needs allowlisting here, so `bigquery.dataEditor` and `dataViewer` were granted at project level, and `bigquery.readSessionUser` was added (the Storage API read needs its own permission).
- The plan expected the candidate near 0.02. It was 0.0135, close to the baseline.
- `.gitignore` had `readme_1.mdpipelines/*.json` on one line after an `Add-Content` without a newline, and `training/requirements.txt` held pasted shell commands. Both fixed.
- Shell variables (`$BUCKET`, `$IMAGE`, `$PROJECT`) were empty in new shells several times and failed at argument parsing.

### Limitations

- The 0.0002 test and val gaps are not tested for significance, so "tie" is the safe description.
- Oracle weather, as on Day 3 (features are actuals, not forecasts).
- One model, one run, one hyperparameter set (copied from the best `bt_resid` trial, not re-tuned for XGBoost).
- The registered model is untested at serving time, and the SDK warned that it could not verify the pipeline artifacts bucket (harmless, the job ran).
