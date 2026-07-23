# DFOCA_20211124 - legacy PACM_20240820 submission, converted to PARS.
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/DFOCA_20211124"

metadata <- read_csv(file.path(dir, "raw/DFOCA_METADATA_20211124.csv"), col_types = cols(.default = col_character()))
detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE) |>
  map_dfr(read_csv, col_types = cols(.default = col_character()))

detections <- detections |>
  mutate(
    SPECIES = case_when(
      SPECIES == "HYAM" ~ "NBWH",
      SPECIES == "MEBI" ~ "SOBW",
      SPECIES == "MMME" ~ "MMME",
      SPECIES == "ZICA" ~ "GOBW",
      TRUE ~ SPECIES
    ),
    CALL_TYPE = case_when(
      SPECIES == "NBWH" & CALL_TYPE == "Frequency modulated upsweep" ~ "OD_CLICK_FM",
      SPECIES == "SOBW" & CALL_TYPE == "Frequency modulated upsweep" ~ "OD_CLICK_FM",
      SPECIES == "MMME" & CALL_TYPE == "Frequency modulated upsweep" ~ "OD_CLICK_FM",
      SPECIES == "GOBW" & CALL_TYPE == "Frequency modulated upsweep" ~ "OD_CLICK_FM",
      TRUE ~ CALL_TYPE
    )
  )


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  organization_code = "DFO",
  project_funding = NA_character_
)
