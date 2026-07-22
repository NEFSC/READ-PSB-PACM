# JASCO_20240925 - legacy PACM_20240820 submission, converted to PARS (T3.2, AD-12).
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/JASCO_20240925"

metadata <- read_csv(file.path(dir, "raw/JASCO_METADATA_20240925T114155Z_.csv"), col_types = cols(.default = col_character()))
detections <- read_csv(file.path(dir, "raw/JASCO_20240915_DETECTIONDATA.csv"), col_types = cols(.default = col_character()))


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  organization_code = "UNH",
  project_funding = NA_character_
)
