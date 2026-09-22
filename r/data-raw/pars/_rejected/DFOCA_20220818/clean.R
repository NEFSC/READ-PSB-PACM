# DFOCA_20220818 - legacy DFO submission, converted to PARS.
#
# Low-frequency (baleen) sei-whale detections only, no deployment metadata: the
# deployments were provided by other submissions - EMBD/STF by DFOCA_20220712,
# MGL by DFOCA_20211124 (all org DFO) - and global referential integrity resolves
# these detections against that metadata. convert_legacy_submission is therefore
# called with metadata = NULL, writing only clean/detectiondata.csv.

library(tidyverse)
source("R/functions.R")

dir <- "data-raw/pars/DFOCA_20220818"

detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE) |>
  map_dfr(read_csv, col_types = cols(.default = col_character()))

detections <- detections |>
  mutate(
    # the sole call type is a descriptive string; map to the SWDS code that
    # clean_detectiondata() remaps to the published SEWH_DS80HZ
    CALL_TYPE = case_when(
      CALL_TYPE == "Full Frequency Downsweep (singlet, doublet, triplet)" & SPECIES == "SEWH" ~ "SWDS",
      TRUE ~ CALL_TYPE
    )
  )

convert_legacy_submission(
  dir,
  metadata = NULL,
  detectiondata = detections,
  organization_code = "DFO"
)
