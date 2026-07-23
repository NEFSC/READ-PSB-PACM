# DFOCA_20230322 - legacy PACM_20240820 submission, converted to PARS.
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/DFOCA_20230322"

metadata <- read_csv(file.path(dir, "raw/DFOCA_METADATA_20230323.csv"), col_types = cols(.default = col_character()))
detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE) |>
  map_dfr(read_csv, col_types = cols(.default = col_character()))

metadata <- metadata |>
  mutate(
    UNIQUE_ID = case_when(
      UNIQUE_ID == "GBK_2019_10" ~ "GBK_2019_10_HF",
      UNIQUE_ID == "SFD_2020_09" ~ "SFD_2020_09_HF",
      TRUE ~ UNIQUE_ID
    )
  )

detections <- detections |>
  mutate(
    UNIQUE_ID = case_when(
      UNIQUE_ID == "WSS_2019_10" ~ "WSS_2019_HF",
      TRUE ~ UNIQUE_ID
    )
  )


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  organization_code = "DFO",
  project_funding = NA_character_
)
