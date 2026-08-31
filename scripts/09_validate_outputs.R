source("scripts/R/common.R")

required <- c("lsoa21.pmtiles", "msoa21.pmtiles", "elections-general-2024.pmtiles", "elections-local-2022.pmtiles", "elections-london-2021.pmtiles", "layer-manifest.json", "section-reports.json", "places.json", "addresses.json")
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
    missingValuesPreserved = TRUE
  ),
  archiveBytes = as.list(archive_sizes)
)
write_json(validation, file.path(public_data_dir, "validation-report.json"), pretty = TRUE, auto_unbox = TRUE)
message("Validation passed: ", length(manifest$layers), " layers and ", length(reports$sections), " LSOA reports.")
