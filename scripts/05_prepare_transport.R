source("scripts/R/common.R")

snapshot_date <- as.character(Sys.Date())
mode_query <- "tube,dlr,tram,overground,elizabeth-line"
line_catalogue <- fromJSON(paste0(sources$tfl_api_base, "/Line/Mode/", mode_query, "/Route"), simplifyVector = FALSE)

tube_colours <- c(
  bakerloo = "#B36305", central = "#E32017", circle = "#FFD300", district = "#00782A",
  `hammersmith-city` = "#F3A9BB", jubilee = "#A0A5A9", metropolitan = "#9B0056",
  northern = "#000000", piccadilly = "#003688", victoria = "#0098D4", `waterloo-city` = "#95CDBA"
)
mode_colours <- c(dlr = "#00A4A7", tram = "#84B817", overground = "#EE7C0E", `elizabeth-line` = "#6950A1")

rail_lines <- list()
rail_stops <- list()
for (line in line_catalogue) {
  line_id <- line$id
  mode <- line$modeName
  message("TfL line: ", line$name)
  sequence <- fromJSON(paste0(sources$tfl_api_base, "/Line/", URLencode(line_id, reserved = TRUE), "/Route/Sequence/all"), simplifyVector = FALSE)
  colour <- if (mode == "tube") unname(tube_colours[[line_id]] %||% "#555555") else unname(mode_colours[[mode]] %||% "#555555")

  for (line_string in sequence$lineStrings %||% list()) {
    paths <- fromJSON(line_string, simplifyVector = FALSE)
    for (path in paths) {
      coordinates <- do.call(rbind, lapply(path, unlist))
      if (nrow(coordinates) < 2) next
      rail_lines[[length(rail_lines) + 1L]] <- st_sf(
        feature_type = "line", mode = mode, route_id = line_id, name = line$name,
        route_color = colour, snapshot_date = snapshot_date,
        geometry = st_sfc(st_linestring(coordinates), crs = 4326)
      )
    }
  }

  for (branch in sequence$stopPointSequences %||% list()) {
    for (stop in branch$stopPoint %||% list()) {
      if (is.null(stop$lon) || is.null(stop$lat)) next
      rail_stops[[length(rail_stops) + 1L]] <- st_sf(
        feature_type = "stop", mode = mode, route_id = line_id, name = stop$name,
        stop_id = stop$id, route_color = colour, snapshot_date = snapshot_date,
        geometry = st_sfc(st_point(c(stop$lon, stop$lat)), crs = 4326)
      )
    }
  }
}

rail_lines <- bind_rows(rail_lines) |> st_as_sf()
rail_stops <- bind_rows(rail_stops) |> st_as_sf() |>
  distinct(mode, stop_id, .keep_all = TRUE)

message("TfL bus routes and stops")
bus_routes_raw <- arcgis_geojson(sources$tfl_bus_routes_features, bbox = c(-0.65, 51.20, 0.45, 51.75))
bus_routes <- bus_routes_raw |>
  transmute(
    feature_type = "line", mode = "bus", route_id = as.character(ROUTE), name = paste("Bus", ROUTE),
    stop_id = NA_character_, route_color = "#C62828", snapshot_date = as.character(as.Date(as.POSIXct(DATE_UPDATED / 1000, origin = "1970-01-01", tz = "UTC"))), geometry
  ) |>
  st_transform(4326)

bus_stops_raw <- arcgis_geojson(sources$tfl_bus_stops_features, bbox = c(-0.65, 51.20, 0.45, 51.75))
bus_stops <- bus_stops_raw |>
  transmute(
    feature_type = "stop", mode = "bus", route_id = as.character(ROUTES), name = as.character(STOP_NAME),
    stop_id = as.character(NAPTAN_ATCO), route_color = "#C62828", snapshot_date = as.character(as.Date(as.POSIXct(DATE_UPDATED / 1000, origin = "1970-01-01", tz = "UTC"))), geometry
  ) |>
  st_transform(4326)

message("TfL Santander Cycle docking stations")
bike_points <- fromJSON(paste0(sources$tfl_api_base, "/BikePoint"), simplifyVector = FALSE)
bikes <- bind_rows(lapply(bike_points, function(point) {
  st_sf(
    feature_type = "stop", mode = "santander", route_id = "santander", name = point$commonName,
    stop_id = point$id, route_color = "#E31B6D", snapshot_date = snapshot_date,
    geometry = st_sfc(st_point(c(point$lon, point$lat)), crs = 4326)
  )
})) |> st_as_sf()

align_columns <- function(data) {
  for (field in c("feature_type", "mode", "route_id", "name", "stop_id", "route_color", "snapshot_date")) {
    if (!field %in% names(data)) data[[field]] <- NA_character_
  }
  data |> select(feature_type, mode, route_id, name, stop_id, route_color, snapshot_date, geometry)
}

transport <- do.call(rbind, lapply(list(rail_lines, rail_stops, bus_routes, bus_stops, bikes), align_columns))
write_geojson(transport, "transport.geojson")

route_order <- function(value) suppressWarnings(as.numeric(gsub("[^0-9]", "", value)))
routes <- sort(unique(bus_routes$route_id), na.last = TRUE)
routes <- routes[order(is.na(route_order(routes)), route_order(routes), routes)]
write_json(lapply(routes, function(route) list(value = route, label = route)), file.path(processed_dir, "bus-routes.json"), pretty = TRUE, auto_unbox = TRUE)
message("Prepared ", nrow(transport), " static TfL line, stop and dock features.")
