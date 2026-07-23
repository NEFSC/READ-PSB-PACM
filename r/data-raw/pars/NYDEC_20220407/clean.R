# NYDEC_20220407 - legacy PACM_20240820 submission, converted to PARS.
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/NYDEC_20220407"

metadata <- read_csv(file.path(dir, "raw/NYDEC_METADATA_20220407.csv"), col_types = cols(.default = col_character()))
detections <- read_csv(file.path(dir, "raw/NYDEC_DETECTIONDATA_20220321.csv"), col_types = cols(.default = col_character()))

metadata <- metadata |>
  mutate(
    SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
  )

detections <- detections |>
  mutate(
    SPECIES = case_when(
      SPECIES == "EUGL" ~ "RIWH",
      TRUE ~ SPECIES
    ),
    CALL_TYPE = case_when(
      SPECIES == "RIWH" & CALL_TYPE == "Upcall" ~ "UPCALL",
      TRUE ~ CALL_TYPE
    ),
    ANALYSIS_SAMPLING_RATE_HZ = coalesce(ANALYSIS_SAMPLING_RATE_HZ, "2000"),
    LOCALIZED_LATITUDE = NA_character_,
    LOCALIZED_LONGITUDE = NA_character_,
    DETECTION_DISTANCE_M = NA_character_,
    LOCALIZATION_DISTANCE_METHOD = NA_character_,
    LOCALIZATION_DISTANCE_PROTOCOL = NA_character_
  ) |>
  rename(CALL_TYPE_CODE = CALL_TYPE, SPECIES_CODE = SPECIES)


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  organization_code = "NYDEC",
  project_funding = NA_character_
)
