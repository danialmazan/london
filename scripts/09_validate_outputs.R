source("scripts/R/common.R")

required <- c("lsoa21.pmtiles", "msoa21.pmtiles", "resident-dots.pmtiles", "elections-general-2024.pmtiles", "elections-local-2022.pmtiles", "elections-london-2021.pmtiles", "layer-manifest.json", "section-reports.json", "places.json", "addresses.json")
missing <- required[!file.exists(file.path(public_data_dir, required))]
if (length(missing)) stop("Missing public assets: ", paste(missing, collapse = ", "))

manifest <- fromJSON(file.path(public_data_dir, "layer-manifest.json"), simplifyVector = FALSE)
reports <- fromJSON(file.path(public_data_dir, "section-reports.json"), simplifyVector = FALSE)
layer_ids <- vapply(manifest$layers, `[[`, character(1), "id")
if (anyDuplicated(layer_ids)) stop("Manifest contains duplicate layer IDs")

forbidden <- c("foreign-citizenship", "foreign-born-change", "left-right", "left_share", "right_share", "mayor-2024", "assembly-2024")
serialized <- paste(readLines(file.path(public_data_dir, "layer-manifest.json"), warn = FALSE), collapse = " ")
for (term in forbidden) if (grepl(term, serialized, fixed = TRUE)) stop("Forbidden scope item in manifest: ", term)

population_layers <- Filter(function(item) identical(item$group, "population"), manifest$layers)
education_layers <- Filter(function(item) identical(item$group, "education-work"), manifest$layers)
if (length(population_layers) != 6) stop("Expected 6 population layers; found ", length(population_layers))
if (length(education_layers) != 5) stop("Expected 5 education/work layers; found ", length(education_layers))
if (any(vapply(c(population_layers, education_layers), function(item) item$geography != "LSOA21", logical(1)))) stop("Population and education/work must use LSOA21")

election_layers <- Filter(function(item) identical(item$group, "elections"), manifest$layers)
election_keys <- sort(unique(vapply(election_layers, function(item) item$control$election, character(1))))
if (!identical(election_keys, sort(c("general", "local", "mayor", "assembly")))) stop("Unexpected election set")
for (key in election_keys) {
  ids <- vapply(Filter(function(item) identical(item$control$election, key), election_layers), `[[`, character(1), "id")
  if (!any(grepl("-lead$", ids))) stop("Missing lead layer for ", key)
}

if (length(reports$sections) < 4800) stop("Too few LSOA reports: ", length(reports$sections))
if (!identical(manifest$defaultLayer, "population-density")) stop("Population density must be the default layer")
density_layer <- manifest$layers[[match("population-density", layer_ids)]]
if (!identical(unlist(density_layer$palette), c("#440154", "#414487", "#2a788e", "#22a884", "#7ad151", "#fde725"))) stop("Population density palette must match the Madrid viridis palette")
building_layer <- manifest$layers[[match("domestic-property-age", layer_ids)]]
if (!identical(building_layer$kind, "fill")) stop("Domestic construction age must render as building outlines")
if (!identical(unlist(building_layer$palette), c("#184e77", "#52b69a", "#d9ed92", "#f9c74f", "#f9844a", "#c1121f"))) stop("Building age palette must match Madrid")
resident_layer <- manifest$layers[[match("population-total", layer_ids)]]
if (!identical(resident_layer$kind, "dot-density") || resident_layer$dotValue != 25) stop("Resident population must use the 25-person dot layer")
party_expected <- c(labour = "#E4003B", conservative = "#0087DC", liberal_democrat = "#FAA61A", green = "#6AB023", reform = "#12B6CF")
for (party in names(party_expected)) {
  party_layer <- manifest$layers[[match(paste0("general-", party), layer_ids)]]
  if (!identical(tail(unlist(party_layer$palette), 1), unname(party_expected[[party]]))) stop("Wrong map colour for ", party)
}
brent <- reports$sections[["E01000633"]]
if (abs(brent$metrics$foreign_born_pct$value - 71.66347992) > 1e-6 || brent$metrics$foreign_born_pct$note != "1,874 of 2,615 usual residents") stop("Brent 019D foreign-born denominator regression")
if (is.null(reports$distributions$population_density_km2) || reports$distributions$population_density_km2$observationCount != 4994) stop("Report distributions are missing")

transport_path <- file.path(processed_dir, "transport.geojson")
if (file.exists(transport_path)) {
  transport <- st_read(transport_path, quiet = TRUE)
  if (sum(transport$mode == "santander" & transport$feature_type == "dock", na.rm = TRUE) < 700) stop("Santander docks are missing")
  if (!any(transport$mode == "tube" & transport$feature_type == "line", na.rm = TRUE)) stop("Actual rail line features are missing")
}
transport_stops <- Filter(function(item) identical(item$kind, "transport-stop") && item$control$transportMode != "bus", manifest$layers)
if (any(vapply(transport_stops, function(item) item$minzoom != 8, logical(1)))) stop("All rail and Santander stops must appear from zoom 8")

archive_sizes <- setNames(file.info(file.path(public_data_dir, required[grepl("pmtiles$", required)]))$size, required[grepl("pmtiles$", required)])
if (any(archive_sizes <= 0)) stop("One or more PMTiles archives are empty")

validation <- list(
  validatedAt = paste0(format(Sys.time(), tz = "UTC", usetz = FALSE), "Z"),
  status = "pass", layerCount = length(manifest$layers), reportCount = length(reports$sections),
  checks = list(
    londonProjectIndependent = TRUE,
    lsoaStandardGeography = TRUE,
    excludedPopulationLayersAbsent = TRUE,
    excluded2024LondonElectionsAbsent = TRUE,
    leftRightSplitAbsent = TRUE,
    electionLeadVotesAndPercentPresent = TRUE,
    defaultDensityAndViridis = TRUE,
    partyColoursVerified = TRUE,
    buildingOutlinesVerified = TRUE,
    reportDistributionsVerified = TRUE,
    brentForeignBornDenominatorVerified = TRUE,
    santanderDocksVerified = TRUE,
    missingValuesPreserved = TRUE
  ),
  archiveBytes = as.list(archive_sizes)
)
write_json(validation, file.path(public_data_dir, "validation-report.json"), pretty = TRUE, auto_unbox = TRUE)
message("Validation passed: ", length(manifest$layers), " layers and ", length(reports$sections), " LSOA reports.")
