library(tidyverse)
library(janitor)
library(sf)

dir <- "data-raw/pars/_rejected/JASCO_20250827_NARWCreport/"

raw_metadata <- read_csv(
  list.files(file.path(dir, "raw"), recursive = TRUE, pattern = "METADATA", full.names = TRUE),
  id = "$file",
  col_types = cols(.default = col_character())
)
tabyl(raw_metadata, `$file`)
raw_detections <- read_csv(
  list.files(file.path(dir, "raw"), recursive = TRUE, pattern = "DETECTIONDATA", full.names = TRUE),
  id = "$file",
  col_types = cols(.default = col_character())
)
tabyl(raw_detections, `$file`)

raw_gpsdata_roseway <- read_csv(
  list.files(file.path(dir, "raw", "Glider_RosewayBasin_Submit_to_NOAA"), recursive = TRUE, pattern = "Track", full.names = TRUE),
  col_types = cols(.default = col_character())
)
gpx_file <- list.files(file.path(dir, "raw", "Seatrack_CapeCod_Submit_to_NOAA"), recursive = TRUE, pattern = "seatrac", full.names = TRUE)
st_layers(gpx_file)
# missing timestamps
raw_gpsdata_capecode <- st_read(
  list.files(file.path(dir, "raw", "Seatrack_CapeCod_Submit_to_NOAA"), recursive = TRUE, pattern = "seatrac", full.names = TRUE),
  layer = "track_points"
)

metadata <- raw_metadata |> 
  mutate(
    UNIQUE_ID = str_replace(UNIQUE_ID, " ", ""),
    PLATFORM_TYPE = case_when(
      PLATFORM_TYPE == "Electric-glider" ~ "ELECTRIC_GLIDER",
      PLATFORM_TYPE == "Surface-vehicle" ~ "SURFACE_VEHICLE",
      TRUE ~ PLATFORM_TYPE
    ),
    INSTRUMENT_TYPE = toupper(INSTRUMENT_TYPE)
  ) |> 
  select(-`$file`)
tabyl(metadata, UNIQUE_ID)
tabyl(metadata, PLATFORM_TYPE, INSTRUMENT_TYPE)
stopifnot(!anyDuplicated(metadata$UNIQUE_ID))

detections <- raw_detections |> 
  filter(!is.na(UNIQUE_ID)) |> 
  mutate(
    UNIQUE_ID = str_replace(UNIQUE_ID, " ", "")
  ) |>
  select(-`$file`)

stopifnot(
  all(detections$UNIQUE_ID %in% metadata$UNIQUE_ID)
)

gpsdata <- raw_gpsdata_roseway |> 
  transmute(
    UNIQUE_ID = "JASCO_RosewayBasin_2024-09_glider",
    DATETIME = Time,
    LATITUDE = Latitude,
    LONGITUDE = Longitude
  )

stopifnot(
  all(detections$UNIQUE_ID %in% metadata$UNIQUE_ID),
  all(gpsdata$UNIQUE_ID %in% metadata$UNIQUE_ID)
)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
write_csv(gpsdata, file.path(dir, "clean/gpsdata.csv"), na = "")
