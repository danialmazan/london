source("scripts/R/common.R")

london_boroughs <- c(
  "City of London", "Barking and Dagenham", "Barnet", "Bexley", "Brent", "Bromley",
  "Camden", "Croydon", "Ealing", "Enfield", "Greenwich", "Hackney", "Hammersmith and Fulham",
  "Haringey", "Harrow", "Havering", "Hillingdon", "Hounslow", "Islington",
  "Kensington and Chelsea", "Kingston upon Thames", "Lambeth", "Lewisham", "Merton",
  "Newham", "Redbridge", "Richmond upon Thames", "Southwark", "Sutton", "Tower Hamlets",
  "Waltham Forest", "Wandsworth", "Westminster"
)

normalise_area <- function(data, code_pattern, name_pattern, code_name, label_name) {
  code_field <- first_matching_name(data, code_pattern)
  name_field <- first_matching_name(data, name_pattern)
  data |>
    transmute(!!code_name := as.character(.data[[code_field]]), !!label_name := as.character(.data[[name_field]]), geometry)
}

message("Fetching ONS LSOA21 boundaries")
lsoa <- arcgis_geojson(sources$ons_lsoa21_features) |>
  normalise_area("LSOA21CD", "LSOA21NM", "section_id", "section_name") |>
  mutate(district = sub(" [0-9]{3}[A-Z]$", "", section_name)) |>
  filter(district %in% london_boroughs) |>
  st_transform(27700)

assert_unique(lsoa, "section_id", "London LSOA21 boundaries")
if (nrow(lsoa) < 4800 || nrow(lsoa) > 5200) stop("Unexpected London LSOA count: ", nrow(lsoa))
london_footprint <- st_union(lsoa)
boroughs <- lsoa |>
  group_by(district) |>
  summarise(geometry = st_union(geometry), .groups = "drop")

message("Fetching ONS MSOA21 boundaries")
msoa <- arcgis_geojson(sources$ons_msoa21_features) |>
  normalise_area("MSOA21CD", "MSOA21NM", "msoa_id", "msoa_name") |>
  mutate(district = sub(" [0-9]{3}$", "", msoa_name)) |>
  filter(district %in% london_boroughs) |>
  st_transform(27700)
assert_unique(msoa, "msoa_id", "London MSOA21 boundaries")

within_london <- function(data) {
  points <- st_point_on_surface(st_transform(data, 27700))
  as.vector(st_within(points, london_footprint, sparse = FALSE)[, 1])
}

message("Fetching election-vintage ward boundaries")
ward22 <- arcgis_geojson(sources$ons_ward22_features) |>
  normalise_area("WD22CD", "WD22NM", "ward_id", "ward_name") |>
  st_transform(27700)
ward22 <- ward22[within_london(ward22), ]
ward22$district <- boroughs$district[max.col(st_intersects(st_point_on_surface(ward22), boroughs, sparse = FALSE), ties.method = "first")]
assert_unique(ward22, "ward_id", "London wards 2022")
if (!setequal(unique(ward22$district), london_boroughs)) {
  stop("London wards 2022 are missing boroughs: ", paste(setdiff(london_boroughs, unique(ward22$district)), collapse = ", "))
}

ward21 <- arcgis_geojson(sources$ons_ward21_features) |>
  normalise_area("WD21CD", "WD21NM", "ward_id", "ward_name") |>
  st_transform(27700)
ward21 <- ward21[within_london(ward21), ]
ward21$district <- boroughs$district[max.col(st_intersects(st_point_on_surface(ward21), boroughs, sparse = FALSE), ties.method = "first")]
assert_unique(ward21, "ward_id", "London wards 2021")

message("Fetching 2024 Westminster constituency boundaries")
constituency <- arcgis_geojson(sources$ons_constituency24_features) |>
  normalise_area("PCON24CD", "PCON24NM", "constituency_id", "constituency_name") |>
  st_transform(27700)
constituency <- constituency[within_london(constituency), ]
constituency$district <- boroughs$district[max.col(st_intersects(st_point_on_surface(constituency), boroughs, sparse = FALSE), ties.method = "first")]
assert_unique(constituency, "constituency_id", "London constituencies 2024")

write_geojson(st_transform(lsoa, 4326), "lsoa21.geojson")
write_geojson(st_transform(msoa, 4326), "msoa21.geojson")
write_geojson(st_transform(ward22, 4326), "wards-2022.geojson")
write_geojson(st_transform(ward21, 4326), "wards-2021.geojson")
write_geojson(st_transform(constituency, 4326), "constituencies-2024.geojson")
write_geojson(st_transform(boroughs, 4326), "boroughs.geojson")

places <- st_transform(boroughs, 4326) |>
  rowwise() |>
  mutate(
    bbox = list(as.numeric(st_bbox(geometry))),
    id = paste0("borough-", gsub("[^a-z0-9]+", "-", tolower(district)))
  ) |>
  ungroup() |>
  transmute(id, name = district, kind = "district", district, bbox)
write_json(places, file.path(public_data_dir, "places.json"), pretty = TRUE, auto_unbox = TRUE)
write_json(list(referenceDate = NA_character_, records = list()), file.path(public_data_dir, "addresses.json"), pretty = TRUE, auto_unbox = TRUE, na = "null")

message("Prepared ", nrow(lsoa), " LSOAs, ", nrow(msoa), " MSOAs, ", nrow(ward22), " 2022 wards, ", nrow(ward21), " 2021 wards, and ", nrow(constituency), " constituencies.")
