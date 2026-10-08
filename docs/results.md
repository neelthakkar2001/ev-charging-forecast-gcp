# Results so far (val = Aug 2023 local, test = Sep 2023 local)

Gate baseline (lowest val WAPE, bucket all): naive_24h, WAPE 0.0133. Day 4's pipeline gate must beat this.

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
- Test numbers for anything fitted arrive on Day 3.

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
