source("scripts/R/common.R")

if (!requireNamespace("data.table", quietly = TRUE)) stop("data.table is required for the LBSM2 archive")

lbsm_url <- "https://data.london.gov.uk/download/2k55d/60d8d648-ed64-4f2d-97e0-02d59d2a9b35/LBSMv2_London.zip"
lbsm_path <- copy_from_temp_if_present("/tmp/london-atlas-lbsm2.zip", "gla-lbsm2-london.zip")
if (!file.exists(lbsm_path)) lbsm_path <- download_cached(lbsm_url, "gla-lbsm2-london.zip")

openmap_url <- "https://api.os.uk/downloads/v1/products/OpenMapLocal/downloads?area=TQ&format=ESRI%C2%AE+Shapefile&redirect"
openmap_zip <- file.path(raw_dir, "os-openmap-local-tq.zip")
if (!file.exists(openmap_zip) || file.info(openmap_zip)$size < 230000000) {
  download.file(openmap_url, openmap_zip, mode = "wb", quiet = FALSE)
}
openmap_dir <- file.path(raw_dir, "os-openmap-local-tq")
building_shp <- file.path(openmap_dir, "TQ_Building.shp")
if (!file.exists(building_shp)) {
  dir.create(openmap_dir, recursive = TRUE, showWarnings = FALSE)
  status <- system2("unzip", c("-j", "-o", shQuote(openmap_zip), "*/TQ_Building.*", "-d", shQuote(openmap_dir)))
  if (!identical(status, 0L) || !file.exists(building_shp)) stop("Could not extract OS OpenMap Local building outlines")
}

message("Reading selected LBSM2 domestic-property fields")
properties <- data.table::fread(
  cmd = paste("unzip -p", shQuote(lbsm_path), "LBSMv2_London.csv"),
  select = c("uprn", "os_topo_toid", "easting", "northing", "administrative_area", "lsoa21cd", "construction_age_band", "construction_age_band_known"),
  na.strings = c("", "NA")
)
properties <- properties[!is.na(easting) & !is.na(northing) & !is.na(construction_age_band)]
properties[, os_topo_toid := as.character(os_topo_toid)]
properties[, location_id := data.table::fifelse(!is.na(os_topo_toid) & os_topo_toid != "", os_topo_toid, paste(easting, northing, sep = "-"))]

age_counts <- properties[, .(band_properties = .N), by = .(location_id, easting, northing, administrative_area, lsoa21cd, construction_age_band)]
data.table::setorder(age_counts, location_id, -band_properties, construction_age_band)
modal <- age_counts[, .SD[1], by = location_id]
totals <- properties[, .(domestic_properties = .N, direct_age_records = sum(construction_age_band_known == 1, na.rm = TRUE)), by = location_id]
modal <- totals[modal, on = "location_id"]
modal[, construction_age_known_pct := 100 * direct_age_records / domestic_properties]
modal[, age_status := data.table::fifelse(construction_age_known_pct >= 99.999, "direct", data.table::fifelse(construction_age_known_pct <= 0.001, "modelled", "mixed"))]

age_order <- c("pre-1900", "1900-1929", "1930-1949", "1950-1966", "1967-1982", "1983-1995", "1996-2011", "2012-onwards")
modal[, age_band_code := match(construction_age_band, age_order)]
if (anyNA(modal$age_band_code)) stop("Unexpected LBSM2 construction age band")

points <- st_as_sf(as.data.frame(modal), coords = c("easting", "northing"), crs = 27700)
london <- st_read(file.path(processed_dir, "lsoa21.geojson"), quiet = TRUE) |> st_transform(27700)
london_bbox <- st_as_sfc(st_bbox(london) + c(-100, -100, 100, 100))
message("Reading OS OpenMap Local building outlines within Greater London")
buildings <- st_read(building_shp, wkt_filter = st_as_text(london_bbox), quiet = TRUE) |>
  st_zm(drop = TRUE, what = "ZM") |>
  transmute(building_id = ID, geometry)

message("Assigning domestic-property locations to building outlines")
matches <- st_intersects(points, buildings)
building_index <- vapply(matches, function(index) if (length(index)) index[[1]] else NA_integer_, integer(1))
assignment <- data.table::as.data.table(st_drop_geometry(points))
assignment[, building_index := building_index]
assignment <- assignment[!is.na(building_index)]
if (!nrow(assignment)) stop("No LBSM2 locations matched OS OpenMap Local building outlines")

building_bands <- assignment[, .(band_properties = sum(domestic_properties)), by = .(building_index, construction_age_band, age_band_code)]
data.table::setorder(building_bands, building_index, -band_properties, age_band_code)
building_modal <- building_bands[, .SD[1], by = building_index]
building_totals <- assignment[, .(
  domestic_properties = sum(domestic_properties),
  direct_age_records = sum(direct_age_records),
  administrative_area = administrative_area[[1]], lsoa21cd = lsoa21cd[[1]]
), by = building_index]
building_summary <- building_totals[building_modal, on = "building_index"]
building_summary[, construction_age_known_pct := 100 * direct_age_records / domestic_properties]
building_summary[, age_status := data.table::fifelse(construction_age_known_pct >= 99.999, "direct", data.table::fifelse(construction_age_known_pct <= 0.001, "modelled", "mixed"))]

outlines <- buildings[building_summary$building_index, ]
outlines <- bind_cols(outlines, as.data.frame(building_summary[, .(construction_age_band, age_band_code, domestic_properties, construction_age_known_pct, age_status, administrative_area, lsoa21cd)])) |>
  st_transform(4326)
destination <- file.path(processed_dir, "domestic-properties.geojsonseq")
if (file.exists(destination)) file.remove(destination)
st_write(outlines, destination, driver = "GeoJSONSeq", quiet = TRUE)

status <- list(status = "withheld", layer = "building-height", reason = "No verified redistributable London-wide height dataset is currently included.", decision = "Keep genuine gaps as No data until an open derivation is completed and validated.", checkedAt = as.character(Sys.Date()), candidateSources = list(sources$emu_height_page, sources$environment_agency_dsm_page, sources$os_openmap_local_page))
write_json(status, file.path(public_data_dir, "building-height-status.json"), pretty = TRUE, auto_unbox = TRUE)
message("Prepared ", nrow(outlines), " OS building outlines with matched domestic-property ages; ", sum(is.na(building_index)), " property locations did not match an outline.")
