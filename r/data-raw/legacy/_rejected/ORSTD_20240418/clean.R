library(tidyverse)
library(janitor)

dir <- "data-raw/submissions/ORSTD_20240418"

raw_metadata <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "METADATA", full.names = TRUE),
  # id = "$file",
  col_types = cols(.default = col_character())
) |> 
  remove_empty()
raw_detections <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE),
  # id = "$file",
  col_types = cols(.default = col_character())
) |> 
  remove_empty()

# SKIP GPS DATA (STATIONARY PLATFORM)
# raw_gpsdata <- read_csv(
#   list.files(file.path(dir, "raw"), pattern = "GPSDATA", full.names = TRUE),
#   # id = "$file",
#   col_types = cols(.default = col_character())
# ) |> 
#   remove_empty()

metadata <- raw_metadata |> 
  mutate(
    UNIQUE_ID = glue::glue("{UNIQUE_ID}-{format(ymd_hms(MONITORING_START_DATETIME), '%Y%m%d')}"),
    PLATFORM_TYPE = case_when(
      PLATFORM_TYPE == "Surface-buoy" ~ "MOORED_SURFACE_BUOY",
      TRUE ~ PLATFORM_TYPE
    ),
    SUBMISSION_DATE = "2024-04-14"
    # INSTRUMENT_TYPE = toupper(INSTRUMENT_TYPE)
  )
tabyl(metadata, UNIQUE_ID)
tabyl(metadata, PLATFORM_TYPE, INSTRUMENT_TYPE)
stopifnot(!anyDuplicated(metadata$UNIQUE_ID))

detections <- raw_detections |> 
  mutate(
    UNIQUE_ID = glue::glue("{UNIQUE_ID}-{format(ymd_hms(ANALYSIS_PERIOD_START_DATETIME), '%Y%m%d')}")
  ) |> 
  filter(!is.na(UNIQUE_ID))
tabyl(detections, UNIQUE_ID, ACOUSTIC_PRESENCE)
stopifnot(
  all(detections$UNIQUE_ID %in% metadata$UNIQUE_ID)
)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
