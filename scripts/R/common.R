suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(readxl)
  library(tidyr)
  library(jsonlite)
  library(yaml)
})

options(timeout = max(1200, getOption("timeout")))

project_root <- normalizePath(getwd(), mustWork = TRUE)
raw_dir <- file.path(project_root, "data", "raw")
processed_dir <- file.path(project_root, "data", "processed")
public_data_dir <- file.path(project_root, "public", "data")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(public_data_dir, recursive = TRUE, showWarnings = FALSE)

sources <- yaml::read_yaml(file.path(project_root, "config", "sources.yml"))

`%||%` <- function(x, y) if (is.null(x)) y else x

london_lad_codes <- sprintf("E090000%02d", 1:33)

download_cached <- function(url, filename, mode = "wb") {
  destination <- file.path(raw_dir, filename)
  if (!file.exists(destination) || file.info(destination)$size == 0) {
    message("Downloading ", filename)
    download.file(url, destination, mode = mode, quiet = FALSE)
  }
  destination
}

safe_percent <- function(numerator, denominator) {
  ifelse(is.na(denominator) | denominator <= 0, NA_real_, 100 * numerator / denominator)
}

percentile_rank <- function(x) {
  valid <- !is.na(x)
  output <- rep(NA_real_, length(x))
  if (sum(valid) > 1) output[valid] <- 100 * (rank(x[valid], ties.method = "average") - 1) / (sum(valid) - 1)
  output
}

quantile_breaks <- function(x, probabilities = seq(0, 1, length.out = 7), digits = 1) {
  if (!any(is.finite(x))) return(c(0, 100))
  values <- as.numeric(quantile(x, probabilities, na.rm = TRUE, names = FALSE, type = 8))
  unique(round(values, digits))
}

first_matching_name <- function(data, pattern) {
  matches <- grep(pattern, names(data), ignore.case = TRUE, value = TRUE)
  if (!length(matches)) stop("No field matches: ", pattern)
  matches[[1]]
}

arcgis_geojson <- function(feature_layer_url, bbox = c(-0.55, 51.20, 0.35, 51.75), page_size = 2000) {
  pages <- list()
  offset <- 0L
  repeat {
    parameters <- c(
      "where=1%3D1",
      paste0("geometry=", paste(bbox, collapse = "%2C")),
      "geometryType=esriGeometryEnvelope",
      "inSR=4326",
      "spatialRel=esriSpatialRelIntersects",
      "outFields=*",
      "returnGeometry=true",
      "outSR=4326",
      paste0("resultOffset=", offset),
      paste0("resultRecordCount=", page_size),
      "f=geojson"
    )
    url <- paste0(feature_layer_url, "/query?", paste(parameters, collapse = "&"))
    page <- suppressWarnings(st_read(url, quiet = TRUE, stringsAsFactors = FALSE))
    if (!nrow(page)) break
    pages[[length(pages) + 1L]] <- page
    # ArcGIS services may enforce a lower maxRecordCount than requested. A
    # short page therefore does not imply that it is the final page.
    offset <- offset + nrow(page)
    if (offset > 10000000L) stop("ArcGIS pagination exceeded its safety limit: ", feature_layer_url)
  }
  if (!length(pages)) stop("ArcGIS service returned no features: ", feature_layer_url)
  bind_rows(pages) |>
    st_as_sf() |>
    st_make_valid()
}

write_geojson <- function(data, filename) {
  destination <- file.path(processed_dir, filename)
  if (file.exists(destination)) file.remove(destination)
  st_write(data, destination, driver = "GeoJSON", quiet = TRUE, delete_dsn = TRUE)
  destination
}

assert_unique <- function(data, field, label) {
  values <- data[[field]]
  if (anyDuplicated(values)) stop(label, " contains duplicate ", field, " values")
  if (any(is.na(values) | values == "")) stop(label, " contains missing ", field, " values")
  invisible(TRUE)
}

copy_from_temp_if_present <- function(temp_path, destination_name) {
  destination <- file.path(raw_dir, destination_name)
  if (!file.exists(destination) && file.exists(temp_path)) file.copy(temp_path, destination)
  destination
}
