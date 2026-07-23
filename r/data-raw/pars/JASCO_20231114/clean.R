# JASCO_20231114 - legacy PACM_20240820 submission, converted to PARS.
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/JASCO_20231114"

metadata <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "METADATA", full.names = TRUE),
  col_types = cols(.default = col_character())
) |> 
  janitor::remove_empty("rows")
detections <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE),
  col_types = cols(.default = col_character())
) |> 
  janitor::remove_empty("rows")

metadata <- metadata |>
  mutate(
    UNIQUE_ID = paste(UNIQUE_ID, "20231114", sep = "_")
  )

detections <- detections |>
  mutate(
    UNIQUE_ID = paste(UNIQUE_ID, "20231114", sep = "_"),
    ANALYSIS_TIME_ZONE = "UTC"
  )


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  organization_code = "JASCO",
  project_funding = NA_character_
)
