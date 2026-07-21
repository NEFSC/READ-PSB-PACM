library(tidyverse)
library(janitor)

dir <- "data-raw/legacy/JASCO_20250715"

raw_metadata <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "METADATA", full.names = TRUE),
  id = "$file",
  col_types = cols(.default = col_character())
)
raw_detections <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE),
  id = "$file",
  col_types = cols(.default = col_character())
)
raw_gpsdata <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "GPSDATA", full.names = TRUE),
  id = "$file",
  col_types = cols(.default = col_character())
)

metadata <- raw_metadata |> 
  mutate(
    UNIQUE_ID = str_replace(UNIQUE_ID, " ", ""),
    PLATFORM_TYPE = case_when(
      PLATFORM_TYPE == "Electric-glider" ~ "ELECTRIC_GLIDER",
      TRUE ~ PLATFORM_TYPE
    ),
    INSTRUMENT_TYPE = toupper(INSTRUMENT_TYPE)
  ) |> 
  select(-`$file`)
tabyl(metadata, UNIQUE_ID)
tabyl(metadata, INSTRUMENT_TYPE, PLATFORM_TYPE)
stopifnot(!anyDuplicated(metadata$UNIQUE_ID))

detections <- raw_detections |> 
  mutate(
    UNIQUE_ID = str_replace(UNIQUE_ID, " ", "")
  ) |> 
  select(-`$file`)

gpsdata <- raw_gpsdata |> 
  mutate(
    UNIQUE_ID = str_replace(UNIQUE_ID, " ", "")
  ) |> 
  select(-`$file`)

stopifnot(
  all(detections$UNIQUE_ID %in% metadata$UNIQUE_ID),
  all(gpsdata$UNIQUE_ID %in% metadata$UNIQUE_ID)
)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
write_csv(gpsdata, file.path(dir, "clean/gpsdata.csv"), na = "")

