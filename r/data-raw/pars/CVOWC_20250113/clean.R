# CVOWC_20250113 - legacy PACM_20240820 submission, converted to PARS (T3.2, AD-12).
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/CVOWC_20250113"

metadata <- read_csv(file.path(dir, "raw/CVOW-C_20250113_METADATA.csv"), col_types = cols(.default = col_character()))
detections <- read_csv(file.path(dir, "raw/CVOW-C_20250113_DETECTIONDATA.csv"), col_types = cols(.default = col_character()))

metadata <- metadata |>
  nest(
    data = c(INSTRUMENT_ID, MONITORING_START_DATETIME, MONITORING_END_DATETIME, RECORDING_DURATION_SECONDS)
  ) |>
  mutate(
    INSTRUMENT_ID = map_chr(data, ~ str_c(unique(.x$INSTRUMENT_ID), collapse = ",")),
    MONITORING_START_DATETIME = map_chr(data, ~ min(.x$MONITORING_START_DATETIME)),
    MONITORING_END_DATETIME = map_chr(data, ~ max(.x$MONITORING_END_DATETIME)),
    RECORDING_DURATION_SECONDS = map_chr(data, ~ as.character(sum(as.numeric(.x$RECORDING_DURATION_SECONDS))))
  ) |>
  select(-data)

detections <- detections |>
  mutate(
    UNIQUE_ID = str_extract(UNIQUE_ID, "^[^_]+_[^_]+_[^_]+_[^_]+_[^_]+")
  )


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  organization_code = "RPS_TT",
  project_funding = NA_character_
)
