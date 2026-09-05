source("scripts/R/common.R")

if (!requireNamespace("data.table", quietly = TRUE)) stop("data.table is required to prepare OS Open Names search")

archive <- file.path(raw_dir, "opname_csv_gb.zip")
if (!file.exists(archive)) {
  metadata <- fromJSON(sources$os_open_names_downloads_api)
  csv_download <- metadata$downloads[metadata$downloads$format == "CSV", , drop = FALSE]
  if (!nrow(csv_download)) stop("OS Open Names API returned no CSV download")
  download.file(csv_download$url[[1]], archive, mode = "wb", quiet = FALSE)
}

headers <- strsplit(system2("unzip", c("-p", archive, "Doc/OS_Open_Names_Header.csv"), stdout = TRUE)[[1]], ",", fixed = TRUE)[[1]]
headers[[1]] <- sub("^\\ufeff", "", headers[[1]])
command <- paste("unzip -p", shQuote(archive), shQuote("Data/TQ*.csv"))
names_data <- data.table::fread(cmd = command, header = FALSE, col.names = headers, showProgress = FALSE)

roads <- names_data[
  REGION == "London" & LOCAL_TYPE == "Named Road" & !is.na(NAME1) & NAME1 != "",
  .(
    name = NAME1,
    district = data.table::fifelse(!is.na(DISTRICT_BOROUGH) & DISTRICT_BOROUGH != "", DISTRICT_BOROUGH, POPULATED_PLACE),
    easting = as.numeric(GEOMETRY_X), northing = as.numeric(GEOMETRY_Y)
  )
]
roads <- roads[order(name, district)][, .(
  easting = median(easting, na.rm = TRUE), northing = median(northing, na.rm = TRUE)
), by = .(name, district)]

points <- st_as_sf(as.data.frame(roads), coords = c("easting", "northing"), crs = 27700) |> st_transform(4326)
coordinates <- st_coordinates(points)
records <- lapply(seq_len(nrow(points)), function(index) unname(list(
  paste0("os-road-", index), points$name[[index]], points$district[[index]],
  round(coordinates[index, 1], 6), round(coordinates[index, 2], 6)
)))

write_json(
  list(referenceDate = "2026-07", records = records),
  file.path(public_data_dir, "addresses.json"), pretty = FALSE, auto_unbox = TRUE, na = "null"
)
if (!any(grepl("^Yalding Road$", points$name, ignore.case = TRUE))) stop("OS Open Names search index is missing Yalding Road")
message("Prepared ", length(records), " official OS Open Names road-search records.")
