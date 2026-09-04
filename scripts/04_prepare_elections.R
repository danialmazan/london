source("scripts/R/common.R")

party_key <- function(value) {
  text <- tolower(trimws(value))
  case_when(
    grepl("labour", text) ~ "labour",
    grepl("conservative", text) ~ "conservative",
    grepl("liberal democrat", text) ~ "liberal_democrat",
    grepl("green", text) ~ "green",
    grepl("reform", text) ~ "reform",
    grepl("independent", text) ~ "independent",
    TRUE ~ "other"
  )
}

party_label <- function(key) recode(key,
  labour = "Labour", conservative = "Conservative", liberal_democrat = "Liberal Democrats",
  green = "Green", reform = "Reform UK", independent = "Independent", other = "Other"
)

summarise_election <- function(long, id_fields, valid_votes = NULL, turnout = NULL, prefix) {
  grouped <- long |>
    mutate(party = party_key(party), votes = as.numeric(votes)) |>
    filter(!is.na(votes), votes >= 0) |>
    group_by(across(all_of(id_fields)), party) |>
    summarise(votes = sum(votes), .groups = "drop")

  totals <- grouped |>
    group_by(across(all_of(id_fields))) |>
    arrange(desc(votes), party, .by_group = TRUE) |>
    summarise(
      leader_key = first(party),
      leader = party_label(first(party)),
      leader_votes = first(votes),
      runner_up_votes = nth(votes, 2, default = 0),
      derived_valid_votes = sum(votes),
      .groups = "drop"
    )
  if (!is.null(valid_votes)) totals <- totals |> left_join(valid_votes, by = id_fields)
  if (!"valid_votes" %in% names(totals)) totals$valid_votes <- totals$derived_valid_votes
  if (!is.null(turnout)) totals <- totals |> left_join(turnout, by = id_fields)
  if (!"turnout_pct" %in% names(totals)) totals$turnout_pct <- NA_real_
  totals <- totals |>
    mutate(
      valid_votes = ifelse(is.na(valid_votes), derived_valid_votes, valid_votes),
      lead_votes = leader_votes - runner_up_votes,
      lead_percent = safe_percent(lead_votes, valid_votes),
      lead_label = paste0(leader, " +", format(lead_votes, big.mark = ",", scientific = FALSE, trim = TRUE), " (", sprintf("%.1f", lead_percent), "%)")
    )

  shares <- grouped |>
    left_join(totals |> select(all_of(id_fields), valid_votes), by = id_fields) |>
    mutate(share = safe_percent(votes, valid_votes)) |>
    filter(party %in% c("labour", "conservative", "liberal_democrat", "green", "reform")) |>
    select(all_of(id_fields), party, share) |>
    pivot_wider(names_from = party, values_from = share, names_prefix = paste0("share_"), values_fill = 0)

  output <- totals |>
    left_join(shares, by = id_fields) |>
    select(-derived_valid_votes)
  names(output)[!names(output) %in% id_fields] <- paste0(names(output)[!names(output) %in% id_fields], "_", prefix)
  output
}

normalise_key <- function(value) {
  value <- tolower(value)
  value <- gsub("['’]", "", value)
  value <- gsub("&", " and ", value, fixed = TRUE)
  value <- gsub("[^a-z0-9]+", " ", value)
  value <- trimws(value)
  gsub(" +", " ", value)
}

# UK general election, 4 July 2024 — official UK Parliament candidate data.
general_path <- copy_from_temp_if_present("/tmp/london-atlas-general-2024.csv", "parliament-general-2024-candidates.csv")
if (!file.exists(general_path)) general_path <- download_cached(sources$parliament_general_2024_candidates_csv, "parliament-general-2024-candidates.csv")
general_raw <- read_csv(general_path, show_col_types = FALSE)
general_long <- general_raw |>
  filter(`English region geographic code` == "E12000007") |>
  transmute(
    constituency_id = `Constituency geographic code`,
    constituency_name = `Constituency name`,
    party = ifelse(`Candidate is standing as independent`, "Independent", `Main party name`),
    votes = `Candidate vote count`
  )
general_valid <- general_raw |>
  filter(`English region geographic code` == "E12000007") |>
  distinct(constituency_id = `Constituency geographic code`, valid_votes = `Election valid vote count`)
general_turnout <- general_raw |>
  filter(`English region geographic code` == "E12000007") |>
  distinct(constituency_id = `Constituency geographic code`, electorate = Electorate, valid_votes = `Election valid vote count`) |>
  transmute(constituency_id, turnout_pct = safe_percent(valid_votes, electorate))
general <- summarise_election(general_long, "constituency_id", general_valid, general_turnout, "general")

# Borough elections, 5 May 2022 — use GLA's published ward party totals, not a new candidate aggregation.
borough_path <- copy_from_temp_if_present("/tmp/london-atlas-borough-2022.xlsx", "gla-borough-elections-2022.xlsx")
if (!file.exists(borough_path)) borough_path <- download_cached(sources$gla_borough_elections_2022_xlsx, "gla-borough-elections-2022.xlsx")
borough_wide <- read_excel(borough_path, sheet = "Ward votes summary")
borough_long <- borough_wide |>
  rename(ward_id = WD22CD, ward_name = `Ward name`, district = Borough) |>
  pivot_longer(-c(ward_id, ward_name, LAD11CD, district), names_to = "party", values_to = "votes") |>
  mutate(votes = as.numeric(votes), ward_join = paste(normalise_key(district), normalise_key(ward_name), sep = "|"))
borough <- summarise_election(borough_long, "ward_join", prefix = "local")

# Mayor and London-wide Assembly ballots, 6 May 2021 — official ward-level release.
london_2021_path <- copy_from_temp_if_present("/tmp/london-atlas-londonelects-2021.xlsx", "london-elects-2021-ward-results.xlsx")
if (!file.exists(london_2021_path)) london_2021_path <- download_cached(sources$london_elects_2021_xlsx, "london-elects-2021-ward-results.xlsx")
raw_2021 <- read_excel(london_2021_path, sheet = "All", col_names = FALSE)
header <- as.character(unlist(raw_2021[2, ]))
data_2021 <- raw_2021[-c(1, 2), ]
names(data_2021) <- make.unique(ifelse(is.na(header) | header == "", paste0("field_", seq_along(header)), header))
data_2021 <- data_2021 |>
  filter(GeogLevel == "Ward") |>
  mutate(
    join_district = normalise_key(Borough),
    join_ward = normalise_key(gsub(" (Ward|Camden)$| - Camden$| [A-Z]{2}$", "", Ward, ignore.case = FALSE)),
    ward_join = paste(join_district, join_ward, sep = "|")
  )

candidate_columns <- 6:25
mayor_long <- data_2021 |>
  select(ward_join, all_of(names(data_2021)[candidate_columns])) |>
  pivot_longer(-ward_join, names_to = "party", values_to = "votes") |>
  mutate(party = sub("^.* - ", "", party), votes = as.numeric(votes))
mayor_valid <- data_2021 |> transmute(ward_join, valid_votes = as.numeric(`Total Good`))
mayor_turnout <- data_2021 |> transmute(ward_join, turnout_pct = safe_percent(as.numeric(`Total Mayor Ballots`), as.numeric(Electorate)))
mayor <- summarise_election(mayor_long, "ward_join", mayor_valid, mayor_turnout, "mayor")

assembly_columns <- 59:76
assembly_long <- data_2021 |>
  select(ward_join, all_of(names(data_2021)[assembly_columns])) |>
  pivot_longer(-ward_join, names_to = "party", values_to = "votes") |>
  mutate(votes = as.numeric(votes))
assembly_valid <- data_2021 |> transmute(ward_join, valid_votes = as.numeric(`Total Good.2`))
assembly_turnout <- data_2021 |> transmute(ward_join, turnout_pct = safe_percent(as.numeric(`Total Assembly Ballots`), as.numeric(Electorate)))
assembly <- summarise_election(assembly_long, "ward_join", assembly_valid, assembly_turnout, "assembly")

constituencies <- st_read(file.path(processed_dir, "constituencies-2024.geojson"), quiet = TRUE) |>
  left_join(general, by = "constituency_id")
wards22 <- st_read(file.path(processed_dir, "wards-2022.geojson"), quiet = TRUE) |>
  mutate(ward_join = paste(normalise_key(district), normalise_key(ward_name), sep = "|")) |>
  left_join(borough, by = "ward_join")
wards21 <- st_read(file.path(processed_dir, "wards-2021.geojson"), quiet = TRUE) |>
  mutate(ward_join = paste(normalise_key(district), normalise_key(ward_name), sep = "|")) |>
  left_join(mayor, by = "ward_join") |>
  left_join(assembly, by = "ward_join")

if (mean(!is.na(constituencies$leader_general)) < 0.99) stop("General election join coverage below 99%")
unmatched_local <- wards22 |> st_drop_geometry() |> filter(is.na(leader_local))
if (sum(unmatched_local$district != "City of London") > 5) stop("Unexpected non-City 2022 ward election mismatches: ", paste(unmatched_local$ward_name[unmatched_local$district != "City of London"], collapse = ", "))
for (borough_name in c("Barking and Dagenham", "Greenwich", "Lambeth")) {
  borough_rows <- wards22$district == borough_name
  if (!any(borough_rows) || any(is.na(wards22$leader_local[borough_rows]))) stop("Incomplete 2022 election coverage for ", borough_name)
}
message("2021 ward match coverage: mayor ", round(100 * mean(!is.na(wards21$leader_mayor)), 1), "%; Assembly ", round(100 * mean(!is.na(wards21$leader_assembly)), 1), "%")

write_geojson(constituencies, "elections-general-2024.geojson")
write_geojson(wards22, "elections-local-2022.geojson")
write_geojson(wards21, "elections-london-2021.geojson")
message("Prepared election results with lead votes and lead percentage of valid votes.")
