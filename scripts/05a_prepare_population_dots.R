source("scripts/R/common.R")

if (!requireNamespace("data.table", quietly = TRUE)) stop("data.table is required")
if (!requireNamespace("s2", quietly = TRUE)) stop("s2 is required")

dot_value <- 25L
dot_seed <- 20240904L

largest_remainder <- function(weights, target, ids) {
  expected <- target * weights / sum(weights)
  allocation <- floor(expected)
  remainder <- as.integer(target - sum(allocation))
  if (remainder > 0L) {
    priority <- order(-(expected - allocation), ids)
    allocation[priority[seq_len(remainder)]] <- allocation[priority[seq_len(remainder)]] + 1L
  }
  as.integer(allocation)
}

message("Reading domestic-property building outlines for resident-dot allocation")
buildings <- st_read(file.path(processed_dir, "domestic-properties.geojsonseq"), quiet = TRUE) |>
  st_transform(27700) |>
  arrange(lsoa21cd, building_id)
population <- read_csv(file.path(processed_dir, "lsoa-statistics.csv"), show_col_types = FALSE) |>
  transmute(lsoa21cd = section_id, population_total, target_dots = as.integer(round(population_total / dot_value)))

building_rows <- split(seq_len(nrow(buildings)), buildings$lsoa21cd)
buildings$allocated_dots <- 0L
for (section in seq_len(nrow(population))) {
  code <- population$lsoa21cd[[section]]
  rows <- building_rows[[code]]
  if (is.null(rows) || !length(rows)) next
  buildings$allocated_dots[rows] <- largest_remainder(
    buildings$domestic_properties[rows], population$target_dots[[section]], buildings$building_id[rows]
  )
}

uncovered <- population$lsoa21cd[!population$lsoa21cd %in% names(building_rows)]
containers <- buildings[buildings$allocated_dots > 0, c("lsoa21cd", "building_id", "allocated_dots")] |>
  mutate(container_id = paste0("building:", building_id), allocation_method = "domestic-property-weighted") |>
  select(lsoa21cd, container_id, allocated_dots, allocation_method)
if (length(uncovered)) {
  message("Using LSOA-polygon fallback for ", paste(uncovered, collapse = ", "))
  fallback <- st_read(file.path(processed_dir, "lsoa21.geojson"), quiet = TRUE) |>
    filter(section_id %in% uncovered) |>
    st_transform(27700) |>
    left_join(population |> select(lsoa21cd, target_dots), by = c("section_id" = "lsoa21cd")) |>
    transmute(lsoa21cd = section_id, container_id = paste0("lsoa-fallback:", section_id), allocated_dots = target_dots, allocation_method = "lsoa-polygon-fallback")
  containers <- rbind(containers, fallback)
}
expected_container <- rep(seq_len(nrow(containers)), containers$allocated_dots)
dot_count <- length(expected_container)
message("Sampling ", dot_count, " dots inside ", nrow(containers), " building outlines")

bounds <- vapply(st_geometry(containers), function(geometry) unname(st_bbox(geometry)), numeric(4))
assigned_bounds <- bounds[, expected_container, drop = FALSE]
assigned_geography <- s2::s2_geog_from_wkb(
  st_as_binary(st_transform(st_geometry(containers), 4326)[expected_container]), check = FALSE
)
sampled_x <- rep(NA_real_, dot_count)
sampled_y <- rep(NA_real_, dot_count)
pending <- seq_len(dot_count)
set.seed(dot_seed)
attempt <- 0L
while (length(pending)) {
  attempt <- attempt + 1L
  x <- runif(length(pending), assigned_bounds[1, pending], assigned_bounds[3, pending])
  y <- runif(length(pending), assigned_bounds[2, pending], assigned_bounds[4, pending])
  candidates <- st_as_sf(data.frame(x, y), coords = c("x", "y"), crs = 27700) |> st_transform(4326)
  accepted <- s2::s2_covers(
    assigned_geography[pending],
    s2::s2_geog_from_wkb(st_as_binary(st_geometry(candidates)), check = FALSE)
  )
  accepted_rows <- pending[accepted]
  sampled_x[accepted_rows] <- x[accepted]
  sampled_y[accepted_rows] <- y[accepted]
  pending <- pending[!accepted]
  if (attempt >= 500L) stop("Resident-dot rejection sampling did not converge")
}

dots <- st_as_sf(
  data.frame(
    section_id = containers$lsoa21cd[expected_container],
    container_id = containers$container_id[expected_container],
    allocation_method = containers$allocation_method[expected_container],
    x = sampled_x,
    y = sampled_y
  ),
  coords = c("x", "y"), crs = 27700
) |>
  st_transform(4326) |>
  select(section_id, container_id, allocation_method)

actual <- table(dots$section_id)
reconciled <- population |>
  mutate(generated_dots = as.integer(actual[lsoa21cd]), generated_dots = ifelse(is.na(generated_dots), 0L, generated_dots))
if (!all(reconciled$target_dots == reconciled$generated_dots)) stop("Resident-dot totals do not reconcile by LSOA")

destination <- file.path(processed_dir, "resident-dots.geojsonseq")
if (file.exists(destination)) file.remove(destination)
st_write(dots, destination, driver = "GeoJSONSeq", quiet = TRUE)
write_json(list(
  dotValue = dot_value,
  randomSeed = dot_seed,
  dotCount = nrow(dots),
  lsoaCount = nrow(population),
  representedPopulation = nrow(dots) * dot_value,
  sourcePopulation = sum(population$population_total),
  allocation = "LSOA totals allocated to OS OpenMap Local outlines in proportion to LBSM2 domestic-property counts",
  lsoaPolygonFallbackCount = length(uncovered)
), file.path(public_data_dir, "resident-dots-metadata.json"), pretty = TRUE, auto_unbox = TRUE)
message("Prepared ", nrow(dots), " modelled resident dots; one dot represents ", dot_value, " residents")
