steps <- c(
  "scripts/01_prepare_boundaries.R",
  "scripts/02_prepare_population.R",
  "scripts/03_prepare_income.R",
  "scripts/04_prepare_elections.R",
  "scripts/05_prepare_transport.R",
  "scripts/05_prepare_buildings.R",
  "scripts/06_build_tiles.R",
  "scripts/07_build_manifest.R",
  "scripts/08_build_area_reports.R",
  "scripts/09_validate_outputs.R"
)

for (step in steps) {
  if (!file.exists(step)) next
  message("\n== ", step, " ==")
  status <- system2(file.path(R.home("bin"), "Rscript"), step)
  if (!identical(status, 0L)) stop("Pipeline failed at ", step)
}
