source("scripts/R/common.R")

income_path <- copy_from_temp_if_present("/tmp/london-atlas-income-fye2023.xlsx", "ons-small-area-income-fye2023.xlsx")
if (!file.exists(income_path)) income_path <- download_cached(sources$ons_income_fye2023_xlsx, "ons-small-area-income-fye2023.xlsx")

read_income <- function(sheet, prefix) {
  data <- read_excel(income_path, sheet = sheet, skip = 3)
  estimate <- first_matching_name(data, "Disposable .*income.*\\(£\\)$")
  upper <- first_matching_name(data, "Upper confidence limit")
  lower <- first_matching_name(data, "Lower confidence limit")
  data |>
    filter(`Region code` == "E12000007") |>
    transmute(
      msoa_id = `MSOA code`,
      msoa_name = `MSOA name`,
      district = `Local authority name`,
      !!paste0(prefix, "_gbp") := .data[[estimate]],
      !!paste0(prefix, "_upper_gbp") := .data[[upper]],
      !!paste0(prefix, "_lower_gbp") := .data[[lower]],
      !!paste0(prefix, "_ci_width_gbp") := .data[[upper]] - .data[[lower]]
    )
}

income <- read_income("Net income before housing costs", "income_bhc") |>
  left_join(read_income("Net income after housing costs", "income_ahc"), by = c("msoa_id", "msoa_name", "district"))

msoa <- st_read(file.path(processed_dir, "msoa21.geojson"), quiet = TRUE) |>
  left_join(income, by = c("msoa_id", "msoa_name", "district"))
for (field in c("income_bhc_gbp", "income_ahc_gbp")) msoa[[paste0(field, "_percentile")]] <- percentile_rank(msoa[[field]])
assert_unique(msoa, "msoa_id", "London MSOA income")
if (mean(!is.na(msoa$income_bhc_gbp)) < 0.99) stop("MSOA income join coverage below 99%")
write_geojson(msoa, "msoa-income.geojson")

iod_path <- download_cached(sources$mhclg_iod2025_csv, "mhclg-iod2025-file7.csv", mode = "wb")
iod <- read_csv(iod_path, show_col_types = FALSE)
lsoa_code <- first_matching_name(iod, "LSOA code")
income_score <- first_matching_name(iod, "^Income Score \\(rate\\)$")
idaci_score <- first_matching_name(iod, "IDACI.*Score \\(rate\\)")
idaopi_score <- first_matching_name(iod, "IDAOPI.*Score \\(rate\\)")
iod_london <- iod |>
  transmute(
    section_id = .data[[lsoa_code]],
    income_deprivation_rate = 100 * .data[[income_score]],
    idaci_rate = 100 * .data[[idaci_score]],
    idaopi_rate = 100 * .data[[idaopi_score]]
  )

lsoa <- st_read(file.path(processed_dir, "lsoa-statistics.geojson"), quiet = TRUE) |>
  left_join(iod_london, by = "section_id")
for (field in c("income_deprivation_rate", "idaci_rate", "idaopi_rate")) lsoa[[paste0(field, "_percentile")]] <- percentile_rank(lsoa[[field]])
if (mean(!is.na(lsoa$income_deprivation_rate)) < 0.99) stop("IoD 2025 join coverage below 99%")
write_geojson(lsoa, "lsoa-statistics.geojson")

write_csv(st_drop_geometry(msoa), file.path(processed_dir, "msoa-income.csv"), na = "")
write_csv(st_drop_geometry(lsoa), file.path(processed_dir, "lsoa-statistics.csv"), na = "")
message("Prepared two MSOA income layers and three LSOA deprivation layers.")
