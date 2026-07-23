# JASCO_20220819 - legacy PACM_20240820 submission, converted to PARS.
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/JASCO_20220819"

metadata <- read_csv(file.path(dir, "raw/JASCO_METADATA_20220819.csv"), col_types = cols(.default = col_character())) |> 
  janitor::remove_empty("rows")
detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE) |>
  map_dfr(read_csv, col_types = cols(.default = col_character())) |> 
  janitor::remove_empty("rows")

metadata <- metadata |>
  mutate(
    SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
  )

detections <- detections |>
  mutate(
    CALL_TYPE = case_when(
      SPECIES == "BLWH" ~ "BLMIX",
      SPECIES == "FIWH" ~ "FWMIX",
      SPECIES == "HUWH" ~ "HWMIX",
      TRUE ~ CALL_TYPE
    ),
    PROTOCOL_REFERENCE = case_when(
      str_starts(PROTOCOL_REFERENCE, "Kowarski et al. 2021; Delarue et al. 20") ~ "Kowarski et al. 2021; Delarue et al. 2022",
      TRUE ~ PROTOCOL_REFERENCE
    )
  )


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  organization_code = "JASCO",
  project_funding = NA_character_
)
