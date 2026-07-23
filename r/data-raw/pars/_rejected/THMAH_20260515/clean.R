library(tidyverse)
library(janitor)

dir <- "data-raw/pars/_rejected/THMAH_20260515"

raw_metadata <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "METADATA", full.names = TRUE),
  id = "$file",
  col_types = cols(.default = col_character())
)
raw_detections <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "DetectionData", full.names = TRUE),
  id = "$file",
  col_types = cols(.default = col_character())
)

metadata <- raw_metadata |> 
  filter(!is.na(UNIQUE_ID)) |> 
  mutate(
    PLATFORM_TYPE = case_when(
      PLATFORM_TYPE == "Bottom-mounted" ~ "BOTTOM_MOUNTED_MOORING",
      TRUE ~ PLATFORM_TYPE
    )
    # INSTRUMENT_TYPE = toupper(INSTRUMENT_TYPE)
  ) |> 
  select(-`$file`)
tabyl(metadata, UNIQUE_ID)
tabyl(metadata, PLATFORM_TYPE, INSTRUMENT_TYPE)
stopifnot(!anyDuplicated(metadata$UNIQUE_ID))

detections <- raw_detections |> 
  filter(!is.na(UNIQUE_ID)) |> 
  select(-`$file`)

stopifnot(
  all(detections$UNIQUE_ID %in% metadata$UNIQUE_ID)
)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
