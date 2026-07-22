# JASCO_20241220 - legacy PACM_20240820 submission, converted to PARS (T3.2, AD-12).
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/JASCO_20241220"

raw_metadata <- read_csv(
  file.path(dir, "raw", c("JASCO_HF_METADATA_20241220T102408Z_.csv", "JASCO_LF_METADATA_20241220T103130Z_.csv")),
  id = "$file",
  col_types = cols(.default = col_character())
)
raw_detections <- read_csv(
  file.path(dir, "raw", c("JASCO_HF_DETECTIONDATA_20241220T102943Z_.csv", "JASCO_LF_DETECTIONDATA_20241220T105331Z_.csv")),
  id = "$file",
  col_types = cols(.default = col_character())
)

metadata <- raw_metadata |> 
  mutate(
    UNIQUE_ID = case_when(
      str_detect(`$file`, "_HF_") ~ glue("{UNIQUE_ID}-HF"),
      str_detect(`$file`, "_LF_") ~ glue("{UNIQUE_ID}-LF"),
      TRUE ~ UNIQUE_ID
    ),
    UNIQUE_ID = str_replace(UNIQUE_ID, " ", ""),
    PLATFORM_TYPE = case_when(
      PLATFORM_TYPE == "Bottom-mounted" ~ "BOTTOM_MOUNTED_MOORING",
      TRUE ~ PLATFORM_TYPE
    )
  ) |> 
  select(-`$file`)
tabyl(metadata, UNIQUE_ID)
stopifnot(!anyDuplicated(metadata$UNIQUE_ID))

analyses <- raw_detections |> 
  janitor::remove_empty("cols") |> 
  mutate(
    UNIQUE_ID = case_when(
      str_detect(`$file`, "_HF_") ~ glue("{UNIQUE_ID}-HF"),
      str_detect(`$file`, "_LF_") ~ glue("{UNIQUE_ID}-LF"),
      TRUE ~ UNIQUE_ID
    ),
    UNIQUE_ID = str_replace(UNIQUE_ID, " ", ""),
    CALL_TYPE_CODE = case_when(
      CALL_TYPE_CODE == "ODCLICK" ~ "OD_CLICK",
      CALL_TYPE_CODE == "ODWHIS" ~ "OD_WHIS",
      TRUE ~ CALL_TYPE_CODE
    )
  ) |> 
  select(-`$file`) |> 
  nest(detections = c(
    ANALYSIS_PERIOD_START_DATETIME, ANALYSIS_PERIOD_END_DATETIME, ANALYSIS_PERIOD_EFFORT_SECONDS,
    ACOUSTIC_PRESENCE, N_VALIDATED_DETECTIONS, CALL_TYPE_CODE, DETECTION_COMMENTS
  ))

stopifnot(
  analyses |> 
    count(UNIQUE_ID, SPECIES_CODE) |>
    filter(n > 1) |> 
    nrow() == 0,
  all(analyses$UNIQUE_ID %in% metadata$UNIQUE_ID)
)

detections <- analyses |> 
  mutate(
    detections = map(detections, function (x) {
      x |> 
        mutate(
          across(
            c(ANALYSIS_PERIOD_START_DATETIME, ANALYSIS_PERIOD_END_DATETIME),
            ymd_hms
          ),
          DATE = as_date(ANALYSIS_PERIOD_START_DATETIME)
        ) |>
        group_by(DATE) |> 
        summarise(
          ANALYSIS_PERIOD_START_DATETIME = min(ANALYSIS_PERIOD_START_DATETIME),
          ANALYSIS_PERIOD_END_DATETIME = max(ANALYSIS_PERIOD_END_DATETIME),
          ANALYSIS_PERIOD_EFFORT_SECONDS = sum(as.numeric(ANALYSIS_PERIOD_EFFORT_SECONDS)),
          ACOUSTIC_PRESENCE = case_when(
            any(ACOUSTIC_PRESENCE == "D") ~ "D",
            any(ACOUSTIC_PRESENCE == "N") ~ "N",
            TRUE ~ NA_character_
          ),
          N_VALIDATED_DETECTIONS = sum(as.integer(N_VALIDATED_DETECTIONS)),
          CALL_TYPE_CODE = paste(unique(na.omit(CALL_TYPE_CODE)), collapse = ","),
          DETECTION_COMMENTS = paste(unique(na.omit(DETECTION_COMMENTS)), collapse = ";"),
          .groups = "drop"
        )
    })
  ) |> 
  unnest(detections) |> 
  select(-DATE)


convert_legacy_submission(
  dir,
  metadata = metadata,
  detectiondata = detections,
  organization_code = "UNH",
  project_funding = NA_character_
)
