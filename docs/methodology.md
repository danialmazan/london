# London Atlas methodology

This is the London version of the original [Madrid Atlas](https://danielalmazan.com/madrid/).

## Geography

LSOA21 is the canonical selectable small area. Population, foreign-born, education and work layers are published at LSOA21. ONS model-based disposable household income is retained at MSOA21. Electoral results remain on their official constituencies or wards. Area reports show the containing native geography; they do not downscale MSOA, ward or constituency values to LSOA.

## Population, education and work

Mid-2019 and mid-2024 population estimates come from ONS LSOA workbooks. Density divides the mid-2024 estimate by polygon area. Age shares use the published age counts. Five-year change compares the two ONS estimates on LSOA21.

Census 2021 TS004 provides country of birth, TS066 economic activity and TS067 highest qualification through Nomis bulk downloads. Foreign-born is residents born outside the UK divided by all usual residents. Activity and employment rates use residents aged 16+; the unemployment rate uses economically active residents; qualification rates use residents aged 16+.

## Income and deprivation

ONS FYE 2023 before- and after-housing-cost income estimates are model-based MSOA values and include their published 95% confidence intervals. Income deprivation, IDACI and IDAOPI are from the English Indices of Deprivation 2025 and are retained at LSOA21.

## Elections

The 2024 general election uses UK Parliament candidacy results and ONS Westminster constituency boundaries. London borough elections 2022 use the GLA ward workbook. The 2021 Mayor and London-wide Assembly ballots use London Elects ward results.

For every area, `lead_votes` is the leader's votes minus the runner-up's votes. `lead_percent` is `lead_votes / valid_votes × 100`. The display combines both as, for example, `Labour +1,830 (6.2%)`. Where the GLA local-election workbook lacks an electorate denominator, turnout remains `No data`.

## Buildings

Construction year comes from London Building Stock Model 2 (LBSM2). Domestic-property locations are spatially matched to OS OpenMap Local generalised building outlines. OS OpenMap Local supplies geometry but no construction-year attribute, while LBSM2 supplies that attribute only for domestic stock; that is why this layer cannot cover non-domestic buildings. Multiple records in one matched outline are consolidated using the modal year band; each feature retains the domestic-property count and share of direct records. Unmatched outlines are not assigned a year. The visible caveat is: **Domestic properties only; year is the modal LBSM2 construction band for each matched building.**

The historical EMU building-height viewer used the same broad LiDAR-derived method family contemplated here, but the former data page no longer exposes a verified redistribution licence. The atlas therefore withholds building height. A future open build should derive height from Environment Agency DSM/DTM data and an open, redistribution-compatible footprint source, then validate coverage and outliers before publication.

## Transport and missing data

Transport is a dated static snapshot, not a live service. Rail paths use actual OpenStreetMap route-relation geometry, combined with TfL API service identity, station locations and colours. Santander docks come from the TfL API; bus routes and stops use official TfL ArcGIS geometry. All source dates and attributions are stored in the features and manifest.

Missing, suppressed, unmatched or uncovered observations remain `No data`; they are never imputed as zero. The GLA 2022 borough-election workbook excludes the City of London's separate Common Council elections, so City wards remain `No data`.
