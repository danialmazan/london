source("scripts/R/common.R")

lsoa <- st_read(file.path(processed_dir, "lsoa-statistics.geojson"), quiet = TRUE) |>
  st_transform(27700)
msoa <- st_read(file.path(processed_dir, "msoa-income.geojson"), quiet = TRUE) |>
  st_transform(27700)
ward22 <- st_read(file.path(processed_dir, "elections-local-2022.geojson"), quiet = TRUE) |>
  st_transform(27700)
ward21 <- st_read(file.path(processed_dir, "elections-london-2021.geojson"), quiet = TRUE) |>
  st_transform(27700)
constituency <- st_read(file.path(processed_dir, "elections-general-2024.geojson"), quiet = TRUE) |>
  st_transform(27700)

points <- st_point_on_surface(lsoa) |>
  select(section_id)
join_one <- function(polygons, fields) {
  st_join(points, polygons |> select(all_of(fields)), left = TRUE) |>
    st_drop_geometry() |>
    distinct(section_id, .keep_all = TRUE)
}

msoa_join <- join_one(msoa, c("msoa_id", "msoa_name", "income_bhc_gbp", "income_bhc_lower_gbp", "income_bhc_upper_gbp", "income_bhc_gbp_percentile", "income_ahc_gbp", "income_ahc_lower_gbp", "income_ahc_upper_gbp", "income_ahc_gbp_percentile"))
ward22_join <- join_one(ward22, names(ward22)[grepl("^(ward_|district$|leader_|lead_|turnout_|share_)", names(ward22))])
ward21_join <- join_one(ward21, names(ward21)[grepl("^(ward_|district$|leader_|lead_|turnout_|share_)", names(ward21))])
constituency_join <- join_one(constituency, names(constituency)[grepl("^(constituency_|district$|leader_|lead_|turnout_|share_)", names(constituency))])

combined <- lsoa |>
  st_drop_geometry() |>
  left_join(msoa_join, by = "section_id") |>
  left_join(ward22_join |> select(-any_of("district")), by = "section_id") |>
  left_join(ward21_join |> select(-any_of("district")), by = "section_id") |>
  left_join(constituency_join |> select(-any_of("district")), by = "section_id")

metric_metadata <- list(
  population_total = c("Resident population", "integer", "residents", "LSOA21", "2024-06-30"),
  population_density_km2 = c("Population density", "integer", "residents/km²", "LSOA21", "2024-06-30"),
  under18_pct = c("Residents under 18", "percent", "%", "LSOA21", "2024-06-30"),
  age65plus_pct = c("Residents aged 65+", "percent", "%", "LSOA21", "2024-06-30"),
  population_change_5y_pct = c("Five-year population change", "percent", "%", "LSOA21", "2019–2024"),
  foreign_born_pct = c("Foreign-born residents", "percent", "%", "LSOA21", "2021-03-21"),
  activity_rate_pct = c("Economic activity", "percent", "%", "LSOA21", "2021-03-21"),
  employment_rate_pct = c("Employment", "percent", "%", "LSOA21", "2021-03-21"),
  unemployment_rate_pct = c("Unemployment", "percent", "%", "LSOA21", "2021-03-21"),
  level4plus_pct = c("Level 4+ qualifications", "percent", "%", "LSOA21", "2021-03-21"),
  low_no_qualifications_pct = c("Low or no qualifications", "percent", "%", "LSOA21", "2021-03-21"),
  income_bhc_gbp = c("Disposable income before housing costs", "currency", "£/year", "MSOA21", "FYE 2023"),
  income_ahc_gbp = c("Disposable income after housing costs", "currency", "£/year", "MSOA21", "FYE 2023"),
  income_deprivation_rate = c("Income deprivation", "percent", "%", "LSOA21", "2025"),
  idaci_rate = c("Income deprivation affecting children", "percent", "%", "LSOA21", "2025"),
  idaopi_rate = c("Income deprivation affecting older people", "percent", "%", "LSOA21", "2025")
)

distribution_for <- function(values, bins = 18L) {
  values <- values[is.finite(values)]
  if (!length(values)) return(NULL)
  limits <- range(values)
  if (limits[[1]] == limits[[2]]) limits[[2]] <- limits[[1]] + 1
  breaks <- seq(limits[[1]], limits[[2]], length.out = bins + 1L)
  histogram <- hist(values, breaks = breaks, plot = FALSE, include.lowest = TRUE, right = TRUE)
  list(
    breaks = unname(histogram$breaks), counts = as.integer(histogram$counts),
    observationCount = length(values), min = unname(min(values)), max = unname(max(values))
  )
}

metric_distributions <- setNames(lapply(names(metric_metadata), function(field) {
  source_data <- if (field %in% c("income_bhc_gbp", "income_ahc_gbp")) st_drop_geometry(msoa) else st_drop_geometry(lsoa)
  distribution_for(source_data[[field]])
}), names(metric_metadata))

metric_item <- function(row, field, metadata) {
  percentile_field <- paste0(field, "_percentile")
  list(
    value = if (is.na(row[[field]])) NULL else unname(row[[field]]),
    percentile = if (!percentile_field %in% names(row) || is.na(row[[percentile_field]])) NULL else unname(row[[percentile_field]]),
    label = metadata[[1]], format = metadata[[2]], unit = metadata[[3]], geography = metadata[[4]], referenceDate = metadata[[5]],
    distribution = metric_distributions[[field]],
    note = if (field == "foreign_born_pct" && !is.na(row$foreign_born_residents) && !is.na(row$census_usual_residents)) paste0(format(row$foreign_born_residents, big.mark = ",", scientific = FALSE), " of ", format(row$census_usual_residents, big.mark = ",", scientific = FALSE), " usual residents") else NULL
  )
}

election_item <- function(row, key, geography, area_id, area_name) {
  get_value <- function(prefix) {
    field <- paste0(prefix, "_", key)
    if (!field %in% names(row) || is.na(row[[field]])) NULL else unname(row[[field]])
  }
  list(
    leader = get_value("leader"), leadVotes = get_value("lead_votes"), leadPercent = get_value("lead_percent"),
    leadLabel = get_value("lead_label"), turnoutPct = get_value("turnout_pct"), validVotes = get_value("valid_votes"),
    geography = geography, areaId = if (is.na(area_id)) NULL else unname(area_id), areaName = if (is.na(area_name)) NULL else unname(area_name),
    shares = setNames(lapply(c("labour", "conservative", "liberal_democrat", "green", "reform"), function(party) get_value(paste0("share_", party))), c("labour", "conservative", "liberal_democrat", "green", "reform"))
  )
}

sections <- setNames(lapply(seq_len(nrow(combined)), function(index) {
  row <- combined[index, , drop = FALSE]
  metrics <- setNames(lapply(names(metric_metadata), function(field) metric_item(row, field, metric_metadata[[field]])), names(metric_metadata))
  list(
    id = row$section_id, name = row$section_name, district = row$district,
    geographies = list(
      lsoa = list(id = row$section_id, name = row$section_name, vintage = "2021"),
      msoa = list(id = row$msoa_id, name = row$msoa_name, vintage = "2021"),
      ward2022 = list(id = row$ward_id.x, name = row$ward_name.x, vintage = "2022"),
      ward2021 = list(id = row$ward_id.y, name = row$ward_name.y, vintage = "2021"),
      constituency = list(id = row$constituency_id, name = row$constituency_name, vintage = "2024")
    ),
    metrics = metrics,
    elections = list(
      general = election_item(row, "general", "Westminster constituency 2024", row$constituency_id, row$constituency_name),
      local = election_item(row, "local", "electoral ward 2022", row$ward_id.x, row$ward_name.x),
      mayor = election_item(row, "mayor", "electoral ward 2021", row$ward_id.y, row$ward_name.y),
      assembly = election_item(row, "assembly", "electoral ward 2021", row$ward_id.y, row$ward_name.y)
    ),
    building = NULL
  )
}), combined$section_id)

manifest <- fromJSON(file.path(public_data_dir, "layer-manifest.json"), simplifyVector = FALSE)
report <- list(
  generatedAt = manifest$generatedAt, version = "1.0.0", canonicalVintage = "2021",
  methodologyUrl = "docs/methodology.md", metricMetadata = metric_metadata,
  references = manifest$references, sections = sections
)
write_json(report, file.path(public_data_dir, "section-reports.json"), pretty = FALSE, auto_unbox = TRUE, na = "null", null = "null", digits = 8)
message("Wrote mixed-geography reports for ", length(sections), " LSOAs.")
