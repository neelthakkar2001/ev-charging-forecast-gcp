"""Go/no-go check for CHARGED Amsterdam, then long-format Parquet for `bq load`.

Run from repo root:  python scripts/prepare_charged.py
Thresholds below are fixed BEFORE looking at the data. Change them only with a note
in docs/go-no-go-decision.md saying why.
"""
import sys
from datetime import date
from pathlib import Path

import pandas as pd

RAW, OUT, DOCS = Path("data/raw"), Path("data/processed"), Path("docs")
SRC_TZ = "Europe/Amsterdam"  # flip to "UTC" if the solar-peak line below says 11-12h
MIN_SITES, MIN_SITE_HOURS, MIN_TOTAL_NONZERO = 50, 1000, 0.95
MIN_WEATHER_OVERLAP, MAX_WEATHER_NULL = 0.99, 0.01
MAX_KW_PER_CHARGER = 5.0  # warn-only: mean kWh per charger-hour

# 1. files parse (any failure raises here)
vol = pd.read_csv(RAW / "volume.csv", index_col=0)
vol.index = pd.to_datetime(vol.index)
vol.columns = vol.columns.astype(int)
w = pd.read_csv(RAW / "weather.csv")
w["time"] = pd.to_datetime(w["time"], format="%Y/%m/%d %H:%M")
sites = pd.read_csv(RAW / "sites.csv").rename(columns={"site": "site_id"}).set_index("site_id")  # remove_zero names the key `site`
info = pd.read_csv(RAW / "info.csv")
res = [("1 files parse", True, f"volume {vol.shape[0]} h x {vol.shape[1]} sites; weather {len(w)} rows")]

# 2. hourly, ~Apr-Sep 2023, no big gaps
steps = vol.index.to_series().diff().dropna()
hourly = float((steps == pd.Timedelta("1h")).mean())
lo, hi = vol.index.min(), vol.index.max()
ok = vol.index.is_monotonic_increasing and hourly >= 0.99 and lo <= pd.Timestamp("2023-04-02") and hi >= pd.Timestamp("2023-09-29")
res.append(("2 hourly, Apr-Sep 2023", ok, f"{lo} -> {hi}, hourly steps {hourly:.3f}"))

# 3. enough signal
n_sites = int(((vol > 0).sum() >= MIN_SITE_HOURS).sum())
nz = float((vol.sum(axis=1) > 0).mean())
res.append(("3 enough non-zero signal", n_sites >= MIN_SITES and nz >= MIN_TOTAL_NONZERO,
            f"{n_sites} sites with >={MIN_SITE_HOURS} non-zero hours (need {MIN_SITES}); city total non-zero {nz:.3f} of hours (need {MIN_TOTAL_NONZERO})"))

# 4. weather joins hourly
overlap = float(vol.index.isin(w["time"]).mean())
dups = int(w["time"].duplicated().sum())
nulls = float(w[["temp", "precip"]].isna().mean().max())
solar_peak = int(w.groupby(w["time"].dt.hour)["solarradiation"].mean().idxmax())
res.append(("4 weather joins hourly", overlap >= MIN_WEATHER_OVERLAP and dups == 0 and nulls <= MAX_WEATHER_NULL,
            f"overlap {overlap:.3f}, dup hours {dups}, max null {nulls:.3f}; solar peak hour {solar_peak}h (13-14 = local time, 11-12 = UTC)"))

# 5. kWh sanity (warn-only)
chargers = int(sites["charger_num"].reindex(vol.columns).sum())
kw = float(vol.to_numpy().sum() / (chargers * len(vol)))
res.append(("5 kWh sanity (warn-only)", kw <= MAX_KW_PER_CHARGER,
            f"{kw:.2f} kWh per charger-hour over {chargers} chargers (info.csv says {info.total_chargers.iloc[0]}); sum {vol.to_numpy().sum():,.0f} kWh vs info.csv {info.total_volume.iloc[0]:,.0f}"))

go = all(r[1] for r in res[:4])
DOCS.mkdir(exist_ok=True)
lines = [f"# Go/no-go decision ({date.today()})", "", "| check | result | numbers |", "|---|---|---|"]
for name, passed, msg in res:
    tag = "PASS" if passed else ("WARN" if name.startswith("5") else "FAIL")
    lines.append(f"| {name} | {tag} | {msg} |")
lines += ["", f"**Decision: {'GO' if go else 'NO-GO'}** (checks 1-4 hard, check 5 warn-only)",
          f"Assumed source timezone: {SRC_TZ}", "", "Notes:", ""]
(DOCS / "go-no-go-decision.md").write_text("\n".join(lines), encoding="utf-8")
print("\n".join(lines))
if not go:
    sys.exit("NO-GO: fall back to Option 3 (BigQuery public data). No Parquet written.")

# Parquet for bq load: UTC microsecond timestamps, long format, zeros kept
OUT.mkdir(parents=True, exist_ok=True)
vol.index = vol.index.tz_localize(SRC_TZ).tz_convert("UTC")
long = vol.melt(ignore_index=False, var_name="site_id", value_name="energy_kwh").rename_axis("ts").reset_index()
long["site_id"] = long["site_id"].astype("int32")
long.to_parquet(OUT / "ev_raw.parquet", index=False, coerce_timestamps="us")
w["ts"] = w["time"].dt.tz_localize(SRC_TZ).dt.tz_convert("UTC")
w.drop(columns="time").to_parquet(OUT / "weather_raw.parquet", index=False, coerce_timestamps="us")
sites.reset_index().to_parquet(OUT / "sites_raw.parquet", index=False)
print(f"wrote {len(long):,} long rows -> {OUT}")
