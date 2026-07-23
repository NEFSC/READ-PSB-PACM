# DFOCA_20220712 - legacy PACM_20240820 submission, converted to PARS.
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/DFOCA_20220712"

metadata <- read_csv(file.path(dir, "raw/DFOCA_METADATA_20220712.csv"), col_types = cols(.default = col_character()))


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = NULL,
  organization_code = "DFO",
  project_funding = NA_character_
)
