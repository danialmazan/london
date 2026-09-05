source("scripts/R/common.R")

lsoa <- read_csv(file.path(processed_dir, "lsoa-statistics.csv"), show_col_types = FALSE)
msoa <- read_csv(file.path(processed_dir, "msoa-income.csv"), show_col_types = FALSE)

palette_blue <- c("#edf3f8", "#ceddea", "#9ebfd5", "#6a9ab9", "#376f95", "#174b70")
palette_viridis <- c("#440154", "#414487", "#2a788e", "#22a884", "#7ad151", "#fde725")
palette_teal <- c("#edf5f2", "#cce3db", "#98cabb", "#62aa95", "#33806d", "#155a4c")
palette_orange <- c("#fff2df", "#fbd8ad", "#f2b779", "#df8e48", "#bc6230", "#843d29")
palette_purple <- c("#f4eff7", "#ddd0e7", "#bea9d1", "#987fb6", "#70558f", "#4c3569")
palette_diverging <- c("#7d2948", "#c16b78", "#ead0cf", "#f3f1e7", "#bad8cf", "#5b9b8c", "#1f625c")
party_colours <- c(labour = "#E4003B", conservative = "#0087DC", liberal_democrat = "#FAA61A", green = "#6AB023", reform = "#12B6CF", independent = "#5A5A5A")
party_palette <- function(colour) grDevices::colorRampPalette(c("#f7f7f4", colour))(6)
party_label <- function(key) recode(key,
  labour = "Labour", conservative = "Conservative", liberal_democrat = "Liberal Democrats",
  green = "Green", reform = "Reform UK", independent = "Independent", other = "Other"
)

tooltip <- function(property, label, format, percentile = NULL, suffix = NULL) {
  item <- list(property = property, label = label, format = format)
  if (!is.null(percentile)) item$percentileProperty <- percentile
  if (!is.null(suffix)) item$suffix <- suffix
  item
}

layer <- function(id, group, label, description, property, data, format, unit, geography,
                  reference_date, source_id, palette = palette_blue, breaks = NULL,
                  short_label = NULL, tooltip_fields = NULL, data_status = "direct", control = NULL) {
  if (is.null(breaks) && format != "text") breaks <- quantile_breaks(data[[property]])
  output <- list(
    id = id, group = group, kind = "choropleth", label = label,
    shortLabel = short_label %||% label, description = description, unit = unit,
    referenceDate = reference_date, geography = geography, sourceIds = list(source_id),
    property = property, palette = palette, breaks = breaks %||% numeric(), format = format,
    minzoom = ifelse(grepl("MSOA|constituency", geography, ignore.case = TRUE), 7, 8), maxzoom = 16,
    opacity = 0.78, tooltip = tooltip_fields %||% list(tooltip(property, label, format)),
    dataStatus = data_status
  )
  if (!is.null(control)) output$control <- control
  output
}

`%||%` <- function(x, y) if (is.null(x)) y else x

layers <- list(
  modifyList(layer("population-total", "population", "Resident population", "1 dot = 25 residents, modelled within residential building outlines.", "population_total", lsoa, "integer", "residents", "LSOA21", "2024-06-30", "resident-dots", palette_blue, short_label = "Residents", tooltip_fields = list(tooltip("population_total", "Residents", "integer", "population_total_percentile")), data_status = "modelled"), list(kind = "dot-density", minzoom = 8, maxzoom = 20, dotValue = 25, dotColors = list(light = "#145c9e", dark = "#f6c85f"), dotRadiusStops = list(c(8, 0.45), c(16, 2.3)), dotOpacityStops = list(c(8, 0.55), c(15, 0.86)))),
  layer("population-density", "population", "Population density", "Mid-2024 residents divided by the ONS LSOA21 polygon area.", "population_density_km2", lsoa, "integer", "residents/km²", "LSOA21", "2024-06-30", "lsoa21", palette_viridis, short_label = "Density", data_status = "derived", tooltip_fields = list(tooltip("population_density_km2", "Residents per km²", "integer", "population_density_km2_percentile"))),
  layer("under-18", "population", "Residents under 18", "Share of mid-2024 residents aged 0–17.", "under18_pct", lsoa, "percent", "%", "LSOA21", "2024-06-30", "lsoa21", palette_teal, short_label = "Under 18", tooltip_fields = list(tooltip("under18_pct", "Under 18", "percent", "under18_pct_percentile"))),
  layer("age-65-plus", "population", "Residents aged 65+", "Share of mid-2024 residents aged 65 or over.", "age65plus_pct", lsoa, "percent", "%", "LSOA21", "2024-06-30", "lsoa21", palette_orange, short_label = "Age 65+", tooltip_fields = list(tooltip("age65plus_pct", "Age 65+", "percent", "age65plus_pct_percentile"))),
  layer("population-change-5y", "population", "Five-year population change", "Change between ONS mid-2019 and mid-2024 estimates, both published on LSOA21 geography.", "population_change_5y_pct", lsoa, "percent", "%", "LSOA21", "2019–2024", "lsoa21", palette_diverging, breaks = c(min(lsoa$population_change_5y_pct, na.rm = TRUE), -8, -4, -1.5, 1.5, 4, 8, max(lsoa$population_change_5y_pct, na.rm = TRUE)), short_label = "5-year change", data_status = "derived", tooltip_fields = list(tooltip("population_change_5y_pct", "Change", "percent", "population_change_5y_pct_percentile"))),
  layer("foreign-born", "population", "Foreign-born residents", "Census 2021 residents born outside the United Kingdom as a share of all usual residents.", "foreign_born_pct", lsoa, "percent", "%", "LSOA21", "2021-03-21", "lsoa21", palette_purple, short_label = "Foreign-born", data_status = "derived", tooltip_fields = list(tooltip("foreign_born_pct", "Born outside UK", "percent", "foreign_born_pct_percentile"))),

  layer("economic-activity", "education-work", "Activity rate", "Economically active residents aged 16+, including full-time students who were active.", "activity_rate_pct", lsoa, "percent", "%", "LSOA21", "2021-03-21", "lsoa21", palette_teal, short_label = "Activity rate", data_status = "derived", tooltip_fields = list(tooltip("activity_rate_pct", "Activity rate", "percent", "activity_rate_pct_percentile"))),
  layer("employment", "education-work", "Employment rate", "Residents aged 16+ in employment as a share of all residents aged 16+.", "employment_rate_pct", lsoa, "percent", "%", "LSOA21", "2021-03-21", "lsoa21", palette_blue, short_label = "Employment rate", data_status = "derived", tooltip_fields = list(tooltip("employment_rate_pct", "Employment rate", "percent", "employment_rate_pct_percentile"))),
  layer("unemployment", "education-work", "Unemployment rate", "Unemployed residents as a share of economically active residents aged 16+.", "unemployment_rate_pct", lsoa, "percent", "%", "LSOA21", "2021-03-21", "lsoa21", palette_orange, short_label = "Unemployment rate", data_status = "derived", tooltip_fields = list(tooltip("unemployment_rate_pct", "Unemployment rate", "percent", "unemployment_rate_pct_percentile"))),
  layer("level-4-plus", "education-work", "Level 4+ qualifications", "Residents aged 16+ whose highest qualification is Level 4 or above.", "level4plus_pct", lsoa, "percent", "%", "LSOA21", "2021-03-21", "lsoa21", palette_purple, short_label = "Level 4+ qual.", data_status = "derived", tooltip_fields = list(tooltip("level4plus_pct", "Level 4+", "percent", "level4plus_pct_percentile"))),
  layer("low-no-qualifications", "education-work", "Low or no qualifications", "Residents aged 16+ with no qualifications or Level 1/entry-level qualifications.", "low_no_qualifications_pct", lsoa, "percent", "%", "LSOA21", "2021-03-21", "lsoa21", palette_orange, short_label = "Low/no qual.", data_status = "derived", tooltip_fields = list(tooltip("low_no_qualifications_pct", "Low or no qualifications", "percent", "low_no_qualifications_pct_percentile"))),

  layer("income-bhc", "income", "Disposable income before housing costs", "ONS model-based mean equivalised disposable household income. Tooltip includes the 95% confidence interval.", "income_bhc_gbp", msoa, "currency", "£/year", "MSOA21", "FYE 2023", "msoa21", palette_blue, short_label = "Before housing", data_status = "modelled", tooltip_fields = list(tooltip("income_bhc_gbp", "Mean income", "currency", "income_bhc_gbp_percentile"), tooltip("income_bhc_lower_gbp", "95% CI lower", "currency"), tooltip("income_bhc_upper_gbp", "95% CI upper", "currency"))),
  layer("income-ahc", "income", "Disposable income after housing costs", "ONS model-based mean equivalised disposable household income after housing costs. Tooltip includes the 95% confidence interval.", "income_ahc_gbp", msoa, "currency", "£/year", "MSOA21", "FYE 2023", "msoa21", palette_purple, short_label = "After housing", data_status = "modelled", tooltip_fields = list(tooltip("income_ahc_gbp", "Mean income", "currency", "income_ahc_gbp_percentile"), tooltip("income_ahc_lower_gbp", "95% CI lower", "currency"), tooltip("income_ahc_upper_gbp", "95% CI upper", "currency"))),
  layer("income-deprivation", "income", "Income deprivation", "Share of people experiencing income deprivation in the English Indices of Deprivation 2025.", "income_deprivation_rate", lsoa, "percent", "%", "LSOA21", "2025", "lsoa21", palette_orange, short_label = "Income deprivation", tooltip_fields = list(tooltip("income_deprivation_rate", "Income deprived", "percent", "income_deprivation_rate_percentile"))),
  layer("idaci", "income", "Income deprivation affecting children", "IDACI: share of children aged 0–15 living in income-deprived families.", "idaci_rate", lsoa, "percent", "%", "LSOA21", "2025", "lsoa21", palette_orange, short_label = "Children (IDACI)", tooltip_fields = list(tooltip("idaci_rate", "IDACI rate", "percent", "idaci_rate_percentile"))),
  layer("idaopi", "income", "Income deprivation affecting older people", "IDAOPI: share of people aged 60+ experiencing income deprivation.", "idaopi_rate", lsoa, "percent", "%", "LSOA21", "2025", "lsoa21", palette_orange, short_label = "Older people (IDAOPI)", tooltip_fields = list(tooltip("idaopi_rate", "IDAOPI rate", "percent", "idaopi_rate_percentile")))
)

election_specs <- list(
  general = list(label = "UK General Election", date = "2024-07-04", geography = "Westminster constituency 2024", source = "elections-general-2024", data = st_drop_geometry(st_read(file.path(processed_dir, "elections-general-2024.geojson"), quiet = TRUE))),
  local = list(label = "London Borough Elections", date = "2022-05-05", geography = "electoral ward 2022", source = "elections-local-2022", data = st_drop_geometry(st_read(file.path(processed_dir, "elections-local-2022.geojson"), quiet = TRUE))),
  mayor = list(label = "Mayor of London", date = "2021-05-06", geography = "electoral ward 2021", source = "elections-london-2021", data = st_drop_geometry(st_read(file.path(processed_dir, "elections-london-2021.geojson"), quiet = TRUE))),
  assembly = list(label = "London-wide Assembly ballot", date = "2021-05-06", geography = "electoral ward 2021", source = "elections-london-2021", data = st_drop_geometry(st_read(file.path(processed_dir, "elections-london-2021.geojson"), quiet = TRUE)))
)

party_catalogue <- fromJSON(file.path(processed_dir, "election-parties.json"))

for (key in names(election_specs)) {
  spec <- election_specs[[key]]
  available_parties <- sub(paste0("_", key, "$"), "", sub("^share_", "", names(spec$data)[grepl(paste0("^share_.*_", key, "$"), names(spec$data))]))
  result_fields <- lapply(available_parties, function(party) {
    match <- party_catalogue[party_catalogue$key == party, , drop = FALSE]
    list(property = paste0("share_", party, "_", key), label = if (nrow(match)) match$label[[1]] else party, color = if (nrow(match)) match$color[[1]] else "#8A6F8F")
  })
  control <- list(election = key, party = "leading", results = result_fields)
  result_palette <- as.vector(rbind(party_catalogue$key, party_catalogue$color))
  layers[[length(layers) + 1]] <- layer(paste0(key, "-result"), "elections", paste0(spec$label, " result"), "Leading party or candidate group.", paste0("leader_key_", key), spec$data, "text", "", spec$geography, spec$date, spec$source, result_palette, numeric(), "Result", list(tooltip(paste0("leader_", key), "Leader", "text"), tooltip(paste0("lead_label_", key), "Lead", "text"), tooltip(paste0("turnout_pct_", key), "Turnout", "percent")), control = control)
  layers[[length(layers) + 1]] <- layer(paste0(key, "-lead"), "elections", paste0(spec$label, " lead"), "Leader's margin over the runner-up. Percentage is the lead as a share of valid votes.", paste0("lead_percent_", key), spec$data, "percent", "% of valid votes", spec$geography, spec$date, spec$source, palette_purple, short_label = "Lead", data_status = "derived", tooltip_fields = list(tooltip(paste0("lead_label_", key), "Lead", "text"), tooltip(paste0("lead_votes_", key), "Lead votes", "integer"), tooltip(paste0("lead_percent_", key), "Lead (% valid votes)", "percent")), control = list(election = key, party = "lead"))
  layers[[length(layers) + 1]] <- layer(paste0(key, "-turnout"), "elections", paste0(spec$label, " turnout"), if (key == "local") "The GLA ward workbook does not publish an electorate denominator; this layer therefore preserves No data rather than estimating turnout." else "Valid and rejected ballots cast as a share of the registered electorate.", paste0("turnout_pct_", key), spec$data, "percent", "%", spec$geography, spec$date, spec$source, palette_teal, short_label = "Turnout", data_status = ifelse(key == "local", "unavailable", "derived"), tooltip_fields = list(tooltip(paste0("turnout_pct_", key), "Turnout", "percent")), control = list(election = key, party = "turnout"))
  for (party in names(party_colours)[1:5]) {
    property <- paste0("share_", party, "_", key)
    layers[[length(layers) + 1]] <- layer(paste0(key, "-", party), "elections", paste0(party_label(party), " vote share"), "Party votes as a share of valid votes.", property, spec$data, "percent", "%", spec$geography, spec$date, spec$source, party_palette(unname(party_colours[[party]])), short_label = party_label(party), data_status = "derived", tooltip_fields = list(tooltip(property, paste0(party_label(party), " share"), "percent")), control = list(election = key, party = party))
  }
}

if (file.exists(file.path(public_data_dir, "domestic-properties.pmtiles"))) {
  age_colours <- c("#184e77", "#52b69a", "#d9ed92", "#f9c74f", "#f9844a", "#c1121f")
  layers[[length(layers) + 1]] <- list(
    id = "domestic-property-age", group = "buildings", kind = "fill",
    label = "Domestic property construction year", shortLabel = "Construction year",
    description = "Domestic properties only; year is the modal LBSM2 construction band for each matched building.",
    methodology = "OS OpenMap Local building outlines matched spatially to LBSM2 domestic-property locations, coloured by the modal construction-year band of domestic property records in each matched outline. OS OpenMap Local does not include construction year, and LBSM2 supplies this attribute only for domestic stock. The tooltip reports the direct/modelled status and property count.",
    unit = "age band", referenceDate = "LBSM2 snapshot October 2024; OS OpenMap Local August 2026", geography = "generalised building outline",
    sourceIds = list("domestic-properties"), property = "construction_year_midpoint", palette = age_colours,
    breaks = c(1700, 1900, 1940, 1960, 1980, 2000, 2027), format = "year", minzoom = 12, maxzoom = 17, opacity = 0.9,
    tooltip = list(
      tooltip("construction_age_band", "Construction year band", "text"),
      tooltip("domestic_properties", "Domestic properties", "integer"),
      tooltip("age_status", "Age evidence", "text"),
      tooltip("construction_age_known_pct", "Directly sourced age records", "percent")
    ),
    dataStatus = "mixed direct/modelled"
  )
}

if (file.exists(file.path(public_data_dir, "transport.pmtiles"))) {
  transport_colours <- c(tube = "#1f5f8b", dlr = "#00A4A7", tram = "#84B817", overground = "#EE7C0E", `elizabeth-line` = "#6950A1", bus = "#C62828", santander = "#E31B6D")
  transport_labels <- c(tube = "Underground", dlr = "DLR", tram = "Trams", overground = "Overground", `elizabeth-line` = "Elizabeth line", bus = "Buses", santander = "Santander Cycles")
  routes <- fromJSON(file.path(processed_dir, "bus-routes.json"), simplifyVector = FALSE)
  for (mode in names(transport_labels)) {
    if (mode != "santander") {
      layers[[length(layers) + 1]] <- list(
        id = paste0("transport-", mode, "-lines"), group = "transport", kind = "transport-line",
        label = paste0(transport_labels[[mode]], " lines"), description = ifelse(mode == "bus", "Dated static TfL route geometry; no live runtime dependency.", "Actual OpenStreetMap route-relation geometry with dated TfL service identity and stops."),
        unit = "", referenceDate = as.character(Sys.Date()), geography = ifelse(mode == "bus", "TfL network geometry", "OSM route relation / TfL service"), sourceIds = list("transport"),
        property = "route_id", palette = unname(transport_colours[[mode]]), breaks = numeric(), format = "text",
        minzoom = 7, maxzoom = 17, opacity = 0.9, lineColor = unname(transport_colours[[mode]]), lineWidth = ifelse(mode == "bus", 0.8, 1.7),
        tooltip = list(tooltip("name", "Line", "text"), tooltip("snapshot_date", "Snapshot", "text")),
        control = c(list(transportMode = mode, routeProperty = "route_id"), if (mode == "bus") list(routes = routes) else list()),
        dataStatus = ifelse(mode == "bus", "direct snapshot", "mixed OSM geometry / TfL metadata")
      )
    }
    layers[[length(layers) + 1]] <- list(
      id = paste0("transport-", mode, "-stops"), group = "transport", kind = "transport-stop",
      label = ifelse(mode == "santander", "Santander Cycle docks", paste0(transport_labels[[mode]], " stops")),
      description = "Dated static TfL stop/dock snapshot; availability is not shown.", unit = "",
      referenceDate = as.character(Sys.Date()), geography = "TfL stop or dock location", sourceIds = list("transport"),
      property = "name", palette = unname(transport_colours[[mode]]), breaks = numeric(), format = "text",
      minzoom = ifelse(mode == "bus", 13, 7), maxzoom = 18, opacity = 0.98, lineColor = unname(transport_colours[[mode]]),
      tooltip = list(tooltip("name", ifelse(mode == "santander", "Dock", "Stop"), "text"), tooltip("snapshot_date", "Snapshot", "text")),
      control = c(list(transportMode = mode, routeProperty = "route_id"), if (mode == "bus") list(routes = routes) else list()),
      dataStatus = "direct snapshot"
    )
  }
}

sources_manifest <- list(
  list(id = "lsoa21", url = "data/lsoa21.pmtiles", sourceLayer = "lsoa21", attribution = "ONS; Nomis; MHCLG © Crown copyright", minzoom = 8, maxzoom = 14),
  list(id = "msoa21", url = "data/msoa21.pmtiles", sourceLayer = "msoa21", attribution = "ONS © Crown copyright", minzoom = 7, maxzoom = 13),
  list(id = "elections-general-2024", url = "data/elections-general-2024.pmtiles", sourceLayer = "constituencies2024", attribution = "UK Parliament; ONS", minzoom = 7, maxzoom = 13),
  list(id = "elections-local-2022", url = "data/elections-local-2022.pmtiles", sourceLayer = "wards2022", attribution = "Greater London Authority; ONS", minzoom = 8, maxzoom = 14),
  list(id = "elections-london-2021", url = "data/elections-london-2021.pmtiles", sourceLayer = "wards2021", attribution = "London Elects; ONS", minzoom = 8, maxzoom = 14)
)
if (file.exists(file.path(public_data_dir, "resident-dots.pmtiles"))) {
  sources_manifest[[length(sources_manifest) + 1]] <- list(id = "resident-dots", url = "data/resident-dots.pmtiles", sourceLayer = "resident_dots", attribution = "ONS; GLA London Building Stock Model 2; OS OpenMap Local © Crown copyright", minzoom = 8, maxzoom = 16)
}
if (file.exists(file.path(public_data_dir, "domestic-properties.pmtiles"))) {
  sources_manifest[[length(sources_manifest) + 1]] <- list(id = "domestic-properties", url = "data/domestic-properties.pmtiles", sourceLayer = "domestic_properties", attribution = "Greater London Authority LBSM2; OS OpenMap Local © Crown copyright", minzoom = 12, maxzoom = 15)
}
if (file.exists(file.path(public_data_dir, "transport.pmtiles"))) {
  sources_manifest[[length(sources_manifest) + 1]] <- list(id = "transport", url = "data/transport.pmtiles", sourceLayer = "transport", attribution = "TfL Open Data; © OpenStreetMap contributors", minzoom = 7, maxzoom = 16)
}

references <- list(
  list(title = "Lower layer Super Output Area population estimates", organisation = "Office for National Statistics", url = sources$ons_population_2022_2024_xlsx, licence = "Open Government Licence v3.0", retrieved = as.character(Sys.Date())),
  list(title = "Census 2021 TS004, TS066 and TS067", organisation = "Office for National Statistics via Nomis", url = "https://www.nomisweb.co.uk/census/2021/bulk", licence = "Open Government Licence v3.0", retrieved = as.character(Sys.Date())),
  list(title = "Small area model-based income estimates, FYE 2023", organisation = "Office for National Statistics", url = sources$ons_income_fye2023_xlsx, licence = "Open Government Licence v3.0", retrieved = as.character(Sys.Date())),
  list(title = "English Indices of Deprivation 2025", organisation = "Ministry of Housing, Communities and Local Government", url = sources$mhclg_iod2025_csv, licence = "Open Government Licence v3.0", retrieved = as.character(Sys.Date())),
  list(title = "General election results 2024", organisation = "UK Parliament", url = sources$parliament_general_2024_candidates_csv, licence = "Open Parliament Licence", retrieved = as.character(Sys.Date())),
  list(title = "Borough Council Election Results 2022", organisation = "Greater London Authority", url = sources$gla_borough_elections_2022_xlsx, licence = "Open Government Licence v2.0", retrieved = as.character(Sys.Date())),
  list(title = "Mayor and London Assembly election results 2021", organisation = "London Elects", url = sources$london_elects_2021_xlsx, licence = "Open Government Licence", retrieved = as.character(Sys.Date()))
)
references[[length(references) + 1]] <- list(title = "London Building Stock Model 2", organisation = "Greater London Authority", url = sources$gla_lbsm2_page, licence = "Open Government Licence", retrieved = as.character(Sys.Date()))
references[[length(references) + 1]] <- list(title = "OS OpenMap Local", organisation = "Ordnance Survey", url = sources$os_openmap_local_page, licence = "Open Government Licence v3.0", retrieved = as.character(Sys.Date()))
references[[length(references) + 1]] <- list(title = "OS Open Names", organisation = "Ordnance Survey", url = sources$os_open_names_page, licence = "Open Government Licence v3.0", retrieved = as.character(Sys.Date()))
references[[length(references) + 1]] <- list(title = "TfL Open Data", organisation = "Transport for London", url = sources$tfl_open_data_page, licence = "TfL open-data terms", retrieved = as.character(Sys.Date()))
references[[length(references) + 1]] <- list(title = "OpenStreetMap rail route relations", organisation = "OpenStreetMap contributors", url = "https://www.openstreetmap.org/copyright", licence = "Open Data Commons Open Database License", retrieved = as.character(Sys.Date()))

manifest <- list(
  generatedAt = paste0(format(Sys.time(), tz = "UTC", usetz = FALSE), "Z"), version = "1.0.0",
  defaultLayer = "population-density", sources = sources_manifest, layers = layers, references = references,
  notes = c(
    "LSOA21 is the standard small-area geography for population, foreign-born, education and work.",
    "Resident dots are a dasymetric model: one dot represents 25 residents allocated to a building outline using domestic-property counts, not an exact person or household location. One unmatched LSOA uses its polygon as a documented fallback.",
    "Census 2021 labour-market measures should be read in the context of the coronavirus pandemic and furlough guidance.",
    "Income estimates use MSOA21; selecting an LSOA does not make an MSOA estimate LSOA-specific.",
    "Election lead percentage is lead votes divided by valid votes, not the winning party's total share.",
    "City of London wards are No data in the 2022 borough-election layers because the City holds separate Common Council elections outside the GLA borough-results workbook.",
    "Missing, suppressed and uncovered observations remain No data and are never replaced with zero."
  )
)

write_json(manifest, file.path(public_data_dir, "layer-manifest.json"), pretty = TRUE, auto_unbox = TRUE, na = "null", null = "null", digits = 8)
message("Wrote manifest with ", length(layers), " visible layers.")
