source("scripts/R/common.R")

if (!requireNamespace("data.table", quietly = TRUE)) stop("data.table is required for the 3.9 million-row LBSM2 archive")

lbsm_url <- "https://data.london.gov.uk/download/2k55d/60d8d648-ed64-4f2d-97e0-02d59d2a9b35/LBSMv2_London.zip"
lbsm_path <- copy_from_temp_if_present("/tmp/london-atlas-lbsm2.zip", "gla-lbsm2-london.zip")
if (!file.exists(lbsm_path)) lbsm_path <- download_cached(lbsm_url, "gla-lbsm2-london.zip")

message("Reading selected LBSM2 fields from the compressed London archive")
command <- paste("unzip -p", shQuote(lbsm_path), "LBSMv2_London.csv")
properties <- data.table::fread(
  cmd = command,
  select = c("uprn", "os_topo_toid", "easting", "northing", "administrative_area", "lsoa21cd", "property_type", "building_use", "construction_age_band", "construction_age_band_known"),
  na.strings = c("", "NA")
)
properties <- properties[!is.na(easting) & !is.na(northing) & !is.na(construction_age_band)]
properties[, os_topo_toid := as.character(os_topo_toid)]

# LBSM2 is a domestic-property model. Multiple UPRNs can share one building coordinate;
# the map keeps one point per coordinate and the modal age band, plus a property count.
properties[, location_id := data.table::fifelse(!is.na(os_topo_toid) & os_topo_toid != "", os_topo_toid, paste(easting, northing, sep = "-"))]
age_counts <- properties[, .(band_properties = .N), by = .(location_id, easting, northing, administrative_area, lsoa21cd, construction_age_band)]
data.table::setorder(age_counts, location_id, -band_properties, construction_age_band)
modal <- age_counts[, .SD[1], by = location_id]
totals <- properties[, .(
  domestic_properties = .N,
  direct_age_records = sum(construction_age_band_known == 1, na.rm = TRUE)
), by = location_id]
modal <- totals[modal, on = "location_id"]
modal[, construction_age_known_pct := 100 * direct_age_records / domestic_properties]
modal[, age_status := data.table::fifelse(construction_age_known_pct >= 99.999, "direct", data.table::fifelse(construction_age_known_pct <= 0.001, "modelled", "mixed"))]

age_order <- c("Pre 1900", "1900-1929", "1930-1949", "1950-1966", "1967-1982", "1983-1995", "1996-2002", "2003-2006", "2007-2011", "2012 onwards")
modal[, age_band_code := match(construction_age_band, age_order)]
modal[is.na(age_band_code), age_band_code := length(age_order) + 1L]

coordinates <- sf::sf_project(from = "EPSG:27700", to = "EPSG:4326", matrix(c(modal$easting, modal$northing), ncol = 2))
point_data <- as.data.frame(modal[, .(location_id, administrative_area, lsoa21cd, construction_age_band, age_band_code, domestic_properties, construction_age_known_pct, age_status)])
point_data$longitude <- coordinates[, 1]
point_data$latitude <- coordinates[, 2]
points <- st_as_sf(point_data, coords = c("longitude", "latitude"), crs = 4326)

destination <- file.path(processed_dir, "domestic-properties.geojsonseq")
if (file.exists(destination)) file.remove(destination)
st_write(points, destination, driver = "GeoJSONSeq", quiet = TRUE)

status <- list(
  status = "withheld",
  layer = "building-height",
  reason = "The EMU Analytics London sample is no longer published at its former page and no redistribution licence has been verified. A London-wide EA LiDAR DSM-minus-DTM derivation also requires an open building-footprint source and a separate high-volume raster build.",
  decision = "Do not publish EMU data or an inferred replacement. Keep genuine gaps as No data until the open derivation is completed and validated.",
  checkedAt = as.character(Sys.Date()),
  candidateSources = list(sources$emu_height_page, sources$environment_agency_dsm_page, sources$os_openmap_local_page)
)
write_json(status, file.path(public_data_dir, "building-height-status.json"), pretty = TRUE, auto_unbox = TRUE)
message("Prepared ", nrow(points), " domestic-property locations; height remains withheld pending a licensable open build.")
