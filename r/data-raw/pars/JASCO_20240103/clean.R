# JASCO_20240103 - legacy PACM_20240820 submission, converted to PARS (T3.2, AD-12).
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/JASCO_20240103"

metadata <- read_csv(file.path(dir, "raw/JASCO_20240103_METADATA.csv"), col_types = cols(.default = col_character())) |> 
  janitor::remove_empty("rows")
detections <- read_csv(file.path(dir, "raw/JASCO_20240103_DETECTIONDATA.csv"), col_types = cols(.default = col_character())) |> 
  janitor::remove_empty("rows")

metadata <- metadata |>
  mutate(
    UNIQUE_ID = paste(UNIQUE_ID, "20240103", sep = "_"),
    LONGITUDE = paste0("-", LONGITUDE)
  )

detections <- detections |>
  mutate(
    UNIQUE_ID = paste(UNIQUE_ID, "20240103", sep = "_"),
    ANALYSIS_TIME_ZONE = "UTC"
  )


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  organization_code = "JASCO",
  project_funding = NA_character_
)
