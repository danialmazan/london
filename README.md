# London Interactive Atlas

An independent, reproducible MapLibre atlas of Greater London built from free official UK sources. It is intentionally separate from the Madrid Atlas and keeps each observation on its native published geography.

## Coverage

- Population, foreign-born, education and work: LSOA21.
- Model-based household income: MSOA21, with 95% confidence intervals.
- Income deprivation, IDACI and IDAOPI: LSOA21.
- Elections: Westminster constituency 2024, ward 2022, and ward 2021.
- Domestic construction year: London Building Stock Model 2 property locations matched to OS building outlines. Domestic properties only; year may be modelled.
- Transport: actual OpenStreetMap rail route geometry with dated TfL service/station metadata, plus official TfL bus geometry and Santander Cycles docks.
- Building height: withheld pending a licensable open London-wide derivation; see `docs/building-height-source-decision.md`.

## Commands

```sh
Rscript scripts/00_run_pipeline.R
npm install
npm test
npm run build
```

The production base path is `/london/`. Generated public assets live in `public/data/`; cached source downloads and intermediate files live in `data/raw/` and `data/processed/`.

## Data rules

Missing, suppressed and uncovered observations remain `No data`. Election lead is leader votes minus runner-up votes; lead percentage divides that margin by valid votes.

The 2022 borough-election source excludes the City of London's separate Common Council elections, so the City's wards remain explicitly `No data`. Party-specific maps use the parties' recognised primary colours.

## Browser analytics opt-out

The HTML entry loads Cloudflare Web Analytics only when `localStorage.getItem("exclude_cf_analytics") !== "1"`. To exclude this browser profile, run `localStorage.setItem("exclude_cf_analytics", "1"); location.reload();` in the site console. To restore tracking, run `localStorage.removeItem("exclude_cf_analytics"); location.reload();`. The preference persists for the exact origin and is shared by all project paths under `https://danielalmazan.com`. Other browsers and profiles retain normal tracking. Reload existing tabs after changing it. No visible settings or other analytics integrations are changed.
