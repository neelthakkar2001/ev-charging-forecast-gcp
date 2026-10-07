# CHARGED data notes
- Source: https://github.com/IntelligentSystemsLab/CHARGED (data/AMS_remove_zero)
- Citable record (v1): https://doi.org/10.5281/zenodo.15638531
- Dataset citation: Z. Guo, "A City-scale and Harmonized Dataset for Global Electric Vehicle Charging Demand Analysis", Zenodo, Jun. 11, 2025, doi: 10.5281/zenodo.15638531.
- Paper: Scientific Data, https://pmc.ncbi.nlm.nih.gov/articles/PMC12271547
- Downloaded: 2026-10-05 from GitHub (not the Zenodo zip); files: volume.csv (69,468,484 B), weather.csv (356,104 B), sites.csv (174,285 B), info.csv (211 B)
- Licence (copied verbatim): GitHub repo = none (no LICENSE file at repo root; API `/license` returns 404, checked 2026-10-07); Zenodo = Creative Commons Attribution 4.0 International (CC BY 4.0); article = "Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License" (Sci Data 2025;12:1254, © The Author(s) 2025)
- Licence note: the sources disagree. Zenodo says CC BY (reuse with credit); the article says CC BY-NC-ND (non-commercial, no derivatives) and names no separate licence for the data; GitHub has none. Cautious reading used here: credit the authors, non-commercial portfolio use only, do not redistribute the data.
- Policy: attribute; publish code and metrics only; never commit or redistribute the data
- Quirks: sites.csv key is `site`, not `site_id`; timestamps are local Amsterdam time (solar peak 13h), Apr-Sep has no DST change;
  volume units fail the sanity check (15.69 kWh per charger-hour); research file said 8,880 chargers, actual is 2,172 chargers / 1,388 sites in this version
