# DFOCA_20220825 - legacy DFO submission, converted to PARS.
#
# Low-frequency (baleen) sei-whale detections only, no deployment metadata: DFO
# analysed the ESRF stations whose deployment metadata JASCO_20220819 provided
# (org JASCO). global referential integrity resolves these detections against
# that metadata by deployment_code, so convert_legacy_submission is called with
# metadata = NULL and organization_code = "DFO" (the analysis org), writing only
# clean/detectiondata.csv.

library(tidyverse)
source("R/functions.R")

dir <- "data-raw/pars/DFOCA_20220825"

detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE) |>
  map_dfr(read_csv, col_types = cols(.default = col_character()))

detections <- detections |>
  mutate(
    # the sole call type is a descriptive string; map to the SWDS code that
    # clean_detectiondata() remaps to the published SEWH_DS80HZ
    CALL_TYPE = case_when(
      CALL_TYPE == "Full Frequency Downsweeps (Singlet, Doublet, Triplet)" & SPECIES == "SEWH" ~ "SWDS",
      TRUE ~ CALL_TYPE
    )
  )

convert_legacy_submission(
  dir,
  metadata = NULL,
  detectiondata = detections,
  organization_code = "DFO"
)
