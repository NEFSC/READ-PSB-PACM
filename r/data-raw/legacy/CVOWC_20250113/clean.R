library(tidyverse)

dir <- "data-raw/legacy/CVOWC_20250113"

metadata <- read_csv(file.path(dir, "raw/CVOW-C_20250113_METADATA.csv"), col_types = cols(.default = col_character()))
detections <- read_csv(file.path(dir, "raw/CVOW-C_20250113_DETECTIONDATA.csv"), col_types = cols(.default = col_character()))

metadata <- metadata |>
  nest(
    data = c(INSTRUMENT_ID, MONITORING_START_DATETIME, MONITORING_END_DATETIME, RECORDING_DURATION_SECONDS)
  ) |>
  mutate(
    INSTRUMENT_ID = map_chr(data, ~ str_c(unique(.x$INSTRUMENT_ID), collapse = ",")),
    MONITORING_START_DATETIME = map_chr(data, ~ min(.x$MONITORING_START_DATETIME)),
    MONITORING_END_DATETIME = map_chr(data, ~ max(.x$MONITORING_END_DATETIME)),
    RECORDING_DURATION_SECONDS = map_chr(data, ~ as.character(sum(as.numeric(.x$RECORDING_DURATION_SECONDS))))
  ) |>
  select(-data)

detections <- detections |>
  mutate(
    UNIQUE_ID = str_extract(UNIQUE_ID, "^[^_]+_[^_]+_[^_]+_[^_]+_[^_]+")
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
