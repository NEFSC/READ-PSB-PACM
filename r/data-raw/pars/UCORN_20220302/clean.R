# UCORN_20220302 - legacy PACM_20240820 submission, converted to PARS.
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/UCORN_20220302"

metadata <- read_csv(file.path(dir, "raw/UCORN_METADATA_20220302.csv"), col_types = cols(.default = col_character()))
detections <- read_csv(file.path(dir, "raw/UCORN_DETECTIONDATA_20220302.csv"), col_types = cols(.default = col_character()))

metadata <- metadata |>
  mutate(
    SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10),
    MONITORING_END_DATETIME = case_when(
      UNIQUE_ID == "CORNELL_MD_2013_DEP3_A3" ~ "2016-01-23T00:00:00Z",
      TRUE ~ MONITORING_END_DATETIME
    )
  )

detections <- detections |>
  mutate(
    SPECIES = case_when(
      SPECIES == "BAAC" ~ "MIWH",
      SPECIES == "BAPH" ~ "FIWH",
      SPECIES == "EUGL" ~ "RIWH",
      SPECIES == "MENO" ~ "HUWH",
      TRUE ~ SPECIES
    ),
    CALL_TYPE = case_when(
      SPECIES == "MIWH" & CALL_TYPE == "Pulse train" ~ "MWPT",
      SPECIES == "FIWH" & CALL_TYPE == "20Hz Pulse" ~ "FWPLS",
      SPECIES == "RIWH" & CALL_TYPE == "Upcall" ~ "UPCALL",
      SPECIES == "HUWH" & CALL_TYPE == "Song & Social" ~ "HWMIX",
    )
  )


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  organization_code = "CORNELL",
  project_funding = NA_character_
)
