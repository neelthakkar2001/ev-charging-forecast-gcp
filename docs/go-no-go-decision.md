# Go/no-go decision (2026-10-05)

| check | result | numbers |
|---|---|---|
| 1 files parse | PASS | volume 4392 h x 1388 sites; weather 4392 rows |
| 2 hourly, Apr-Sep 2023 | PASS | 2023-04-01 00:00:00 -> 2023-09-30 23:00:00, hourly steps 1.000 |
| 3 enough non-zero signal | PASS | 1388 sites with >=1000 non-zero hours (need 50); city total non-zero 1.000 of hours (need 0.95) |
| 4 weather joins hourly | PASS | overlap 1.000, dup hours 0, max null 0.000; solar peak hour 13h (13-14 = local time, 11-12 = UTC) |
| 5 kWh sanity (warn-only) | WARN | 15.69 kWh per charger-hour over 2172 chargers (info.csv says 2172); sum 149,692,010 kWh vs info.csv 239,175,391 |

**Decision: GO** (checks 1-4 hard, check 5 warn-only)
Assumed source timezone: Europe/Amsterdam

Notes:
- Check 5 WARN: 15.69 kWh per charger-hour is physically impossible (a charger cannot average 15.7 kW around the clock), and the file total (149.7M kWh) is about 63% of the `info.csv` total (239.2M kWh). So `energy_kwh` is probably not literal kWh (smoothing, double counting or a unit issue). It does not block the project: WAPE and MAE-vs-baseline are scale-free. Recorded as a limitation.
- Timezone: solar radiation peaks at 13h, so the source timestamps are local Amsterdam time. They are converted to UTC before loading. The whole window is summer time (UTC+2), so there is no DST change and the first hour is 2023-03-31 22:00 UTC.
- Surprises: all 1,388 sites have at least 1,000 non-zero hours (the check only needed 50). The charger count (2,172) matches `info.csv`, but an earlier summary of the dataset quoted 8,880 chargers for Amsterdam. Thresholds were not changed after seeing the data.
