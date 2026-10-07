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
