library(tidyverse)
library(janitor)

dir <- "data-raw/submissions/JASCO_20260114_EW1-June-October/"

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

metadata <- raw_metadata |> 
  mutate(
    PLATFORM_TYPE = case_when(
      PLATFORM_TYPE == "Surface-buoy" ~ "MOORED_SURFACE_BUOY",
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
    UNIQUE_ID = str_replace(UNIQUE_ID, "250701|250801|250901|251001", "250601"),
  ) |> 
  select(-`$file`)

stopifnot(
  all(detections$UNIQUE_ID %in% metadata$UNIQUE_ID)
)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
