# London Interactive Atlas

An independent, reproducible MapLibre atlas of Greater London built from free official UK sources. It is intentionally separate from the Madrid Atlas and keeps each observation on its native published geography.

## Coverage

- Population, foreign-born, education and work: LSOA21.
- Model-based household income: MSOA21, with 95% confidence intervals.
- Income deprivation, IDACI and IDAOPI: LSOA21.
- Elections: Westminster constituency 2024, ward 2022, and ward 2021.
- Domestic construction age: London Building Stock Model 2 property locations. Domestic properties only; age may be modelled.
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

Missing, suppressed and uncovered observations remain `No data`. Foreign citizenship, foreign-born change, left/right electoral blocs, and the 2024 London mayor/Assembly results are deliberately absent. Election lead is leader votes minus runner-up votes; lead percentage divides that margin by valid votes.

The 2022 borough-election source excludes the City of London's separate Common Council elections, so the City's wards remain explicitly `No data`. Party-specific maps use the parties' recognised primary colours.
