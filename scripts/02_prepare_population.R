source("scripts/R/common.R")

population_2019_path <- copy_from_temp_if_present("/tmp/london-atlas-pop-2019-2022.xlsx", "ons-lsoa-population-2019-2022.xlsx")
if (!file.exists(population_2019_path)) population_2019_path <- download_cached(sources$ons_population_2019_2022_xlsx, "ons-lsoa-population-2019-2022.xlsx")
population_2024_path <- copy_from_temp_if_present("/tmp/london-atlas-pop-2022-2024.xlsx", "ons-lsoa-population-2022-2024.xlsx")
if (!file.exists(population_2024_path)) population_2024_path <- download_cached(sources$ons_population_2022_2024_xlsx, "ons-lsoa-population-2022-2024.xlsx")

read_population_sheet <- function(path, sheet) {
  data <- read_excel(path, sheet = sheet, skip = 3)
  names(data)[1:5] <- c("lad_code", "district", "section_id", "section_name", "population_total")
  data |>
    filter(lad_code %in% london_lad_codes) |>
    mutate(across(-c(lad_code, district, section_id, section_name), as.numeric))
}

population_2019 <- read_population_sheet(population_2019_path, "Mid-2019 LSOA 2021") |>
  select(section_id, population_2019 = population_total)
population_2024_raw <- read_population_sheet(population_2024_path, "Mid-2024 LSOA 2021")

age_columns <- grep("^[FM][0-9]+\\+?$", names(population_2024_raw), value = TRUE)
ages <- as.integer(gsub("[^0-9]", "", age_columns))
under18_columns <- age_columns[ages < 18]
age65plus_columns <- age_columns[ages >= 65]

population <- population_2024_raw |>
  mutate(
    under18_count = rowSums(across(all_of(under18_columns)), na.rm = TRUE),
    age65plus_count = rowSums(across(all_of(age65plus_columns)), na.rm = TRUE),
    under18_pct = safe_percent(under18_count, population_total),
    age65plus_pct = safe_percent(age65plus_count, population_total)
  ) |>
  select(section_id, section_name, district, population_total, under18_pct, age65plus_pct) |>
  left_join(population_2019, by = "section_id") |>
  mutate(population_change_5y_pct = safe_percent(population_total - population_2019, population_2019))

read_nomis_lsoa <- function(code, url) {
  temp_path <- paste0("/tmp/london-atlas-ts", code, ".zip")
  filename <- paste0("nomis-ts", code, ".zip")
  zip_path <- copy_from_temp_if_present(temp_path, filename)
  if (!file.exists(zip_path)) zip_path <- download_cached(url, filename)
  read_csv(unz(zip_path, paste0("census2021-ts", code, "-lsoa.csv")), show_col_types = FALSE)
}

ts004 <- read_nomis_lsoa("004", sources$nomis_ts004_zip)
foreign_total <- first_matching_name(ts004, "Country of birth: Total")
uk_born <- first_matching_name(ts004, "Europe: United Kingdom")
foreign_born <- ts004 |>
  transmute(
    section_id = `geography code`,
    census_usual_residents = .data[[foreign_total]],
    uk_born_residents = .data[[uk_born]],
    foreign_born_residents = .data[[foreign_total]] - .data[[uk_born]],
    foreign_born_pct = safe_percent(foreign_born_residents, census_usual_residents)
  ) |>
  filter(section_id %in% population$section_id)

ts066 <- read_nomis_lsoa("066", sources$nomis_ts066_zip)
activity_total <- first_matching_name(ts066, "Total: All usual residents aged 16")
active_nonstudent <- first_matching_name(ts066, "active \\(excluding full-time students\\)$")
employed_nonstudent <- first_matching_name(ts066, "excluding full-time students\\):In employment$")
unemployed_nonstudent <- first_matching_name(ts066, "excluding full-time students\\): Unemployed$")
active_student <- first_matching_name(ts066, "active and a full-time student$")
employed_student <- first_matching_name(ts066, "active and a full-time student:In employment$")
unemployed_student <- first_matching_name(ts066, "active and a full-time student: Unemployed$")
education_work <- ts066 |>
  transmute(
    section_id = `geography code`,
    activity_denominator = .data[[activity_total]],
    active_count = .data[[active_nonstudent]] + .data[[active_student]],
    employed_count = .data[[employed_nonstudent]] + .data[[employed_student]],
    unemployed_count = .data[[unemployed_nonstudent]] + .data[[unemployed_student]],
    activity_rate_pct = safe_percent(active_count, activity_denominator),
    employment_rate_pct = safe_percent(employed_count, activity_denominator),
    unemployment_rate_pct = safe_percent(unemployed_count, active_count)
  ) |>
  filter(section_id %in% population$section_id)

ts067 <- read_nomis_lsoa("067", sources$nomis_ts067_zip)
qualification_total <- first_matching_name(ts067, "Total: All usual residents aged 16")
no_qualification <- first_matching_name(ts067, "No qualifications$")
level_one <- first_matching_name(ts067, "Level 1 and entry level")
level_four <- first_matching_name(ts067, "Level 4 qualifications and above")
qualifications <- ts067 |>
  transmute(
    section_id = `geography code`,
    level4plus_pct = safe_percent(.data[[level_four]], .data[[qualification_total]]),
    low_no_qualifications_pct = safe_percent(.data[[no_qualification]] + .data[[level_one]], .data[[qualification_total]])
  ) |>
  filter(section_id %in% population$section_id)

lsoa <- st_read(file.path(processed_dir, "lsoa21.geojson"), quiet = TRUE) |>
  st_transform(27700) |>
  mutate(area_km2 = as.numeric(st_area(geometry)) / 1e6)

statistics <- lsoa |>
  select(section_id, section_name, district, area_km2) |>
  left_join(population, by = c("section_id", "section_name", "district")) |>
  left_join(foreign_born, by = "section_id") |>
  left_join(education_work, by = "section_id") |>
  left_join(qualifications, by = "section_id") |>
  mutate(population_density_km2 = population_total / area_km2)

metric_fields <- c(
  "population_total", "population_density_km2", "under18_pct", "age65plus_pct",
  "population_change_5y_pct", "foreign_born_pct", "activity_rate_pct",
  "employment_rate_pct", "unemployment_rate_pct", "level4plus_pct", "low_no_qualifications_pct"
)
for (field in metric_fields) statistics[[paste0(field, "_percentile")]] <- percentile_rank(statistics[[field]])

assert_unique(statistics, "section_id", "London LSOA statistics")
if (mean(!is.na(statistics$population_total)) < 0.99) stop("Population join coverage below 99%")
if (mean(!is.na(statistics$foreign_born_pct)) < 0.99) stop("TS004 join coverage below 99%")
if (mean(!is.na(statistics$activity_rate_pct)) < 0.99) stop("TS066 join coverage below 99%")
if (mean(!is.na(statistics$level4plus_pct)) < 0.99) stop("TS067 join coverage below 99%")

write_geojson(st_transform(statistics, 4326), "lsoa-statistics.geojson")
write_csv(st_drop_geometry(statistics), file.path(processed_dir, "lsoa-statistics.csv"), na = "")
message("Prepared population, foreign-born, education and work measures for ", nrow(statistics), " LSOAs.")
