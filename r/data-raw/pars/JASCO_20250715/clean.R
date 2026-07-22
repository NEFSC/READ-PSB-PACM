# JASCO_20250715 - legacy PACM_20240820 submission, converted to PARS (T3.2, AD-12).
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/JASCO_20250715"

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



convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  gpsdata = gpsdata,
  organization_code = "RUTGERS",
  project_funding = NA_character_
)
