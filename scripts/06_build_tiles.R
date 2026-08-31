source("scripts/R/common.R")

tippecanoe <- Sys.which("tippecanoe")
if (!nzchar(tippecanoe)) stop("tippecanoe is required: brew install tippecanoe")

build_archive <- function(input, output, layer, minzoom = 8, maxzoom = 14, extra = character(), unlimited_tiles = TRUE) {
  input_path <- file.path(processed_dir, input)
  output_path <- file.path(public_data_dir, output)
  if (!file.exists(input_path)) stop("Missing tile input: ", input_path)
  if (file.exists(output_path)) file.remove(output_path)
  arguments <- c(
    "--force", "--quiet", "--no-feature-limit", if (unlimited_tiles) "--no-tile-size-limit" else character(),
    paste0("--minimum-zoom=", minzoom), paste0("--maximum-zoom=", maxzoom),
    paste0("--layer=", layer), paste0("--output=", output_path), extra, input_path
  )
  status <- system2(tippecanoe, arguments)
  if (!identical(status, 0L)) stop("tippecanoe failed for ", input)
  message(output, ": ", round(file.info(output_path)$size / 1024^2, 1), " MB")
}

build_archive("lsoa-statistics.geojson", "lsoa21.pmtiles", "lsoa21", 8, 14, "--coalesce-densest-as-needed")
build_archive("msoa-income.geojson", "msoa21.pmtiles", "msoa21", 7, 13, "--coalesce-densest-as-needed")
build_archive("elections-general-2024.geojson", "elections-general-2024.pmtiles", "constituencies2024", 7, 13)
build_archive("elections-local-2022.geojson", "elections-local-2022.pmtiles", "wards2022", 8, 14)
build_archive("elections-london-2021.geojson", "elections-london-2021.pmtiles", "wards2021", 8, 14)

if (file.exists(file.path(processed_dir, "transport.geojson"))) {
  build_archive("transport.geojson", "transport.pmtiles", "transport", 7, 16, "--drop-densest-as-needed")
}
if (file.exists(file.path(processed_dir, "domestic-properties.geojsonseq"))) {
  build_archive("domestic-properties.geojsonseq", "domestic-properties.pmtiles", "domestic_properties", 11, 15, "--drop-densest-as-needed", unlimited_tiles = FALSE)
}
if (file.exists(file.path(processed_dir, "building-heights.geojson"))) {
  build_archive("building-heights.geojson", "building-heights.pmtiles", "building_heights", 11, 16, "--drop-densest-as-needed")
}
