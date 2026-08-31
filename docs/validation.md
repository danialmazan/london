# Validation record

The reproducible validator checks:

- exactly 4,994 London LSOA21 reports;
- six population layers and five education/work layers;
- both MSOA income estimates and all three LSOA deprivation indicators;
- general 2024, borough 2022, mayor 2021 and Assembly 2021 result/lead layers;
- absence of foreign-citizenship, foreign-born-change, left/right and London-2024 layers;
- array-valued source references, source archives and required PMTiles files;
- explicit `No data` preservation and the domestic-property caveat.

Current checks pass with 62 visible layers. TypeScript validation, 13 frontend/data tests and the production Vite build also pass. Desktop and 390×844 browser checks show a working MapLibre map, controls, responsive layer sheet, native-geography election selectors and no console warnings or errors.
