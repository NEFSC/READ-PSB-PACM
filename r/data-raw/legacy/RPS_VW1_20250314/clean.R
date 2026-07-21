library(tidyverse)

dir <- "data-raw/legacy/RPS_VW1_20250314"


raw_metadata <- list.files(file.path(dir, "raw"), pattern = "METADATA", full.names = TRUE, recursive = TRUE) |> 
  map_dfr(function (x) {
    read_csv(
      x,
      col_types = cols(.default = col_character())
    ) |> 
      remove_empty(which = c("rows", "cols")) |> 
      mutate(
        `$file` = x,
        .before = 1
      )
  })
raw_metadata$UNIQUE_ID

raw_detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE, recursive = TRUE) |> 
  map_dfr(function (x) {
    read_csv(
      x,
      col_types = cols(.default = col_character())
    ) |> 
      remove_empty(which = c("rows", "cols")) |> 
      mutate(
        `$file` = x,
        .before = 1
      )
  })
unique(raw_detections$UNIQUE_ID)


metadata <- raw_metadata |>
  nest(
    data = c(INSTRUMENT_ID, MONITORING_START_DATETIME, MONITORING_END_DATETIME, RECORDING_DURATION_SECONDS)
  ) |>
  mutate(
    INSTRUMENT_ID = map_chr(data, ~ str_c(unique(.x$INSTRUMENT_ID), collapse = ",")),
    MONITORING_START_DATETIME = map_chr(data, ~ min(.x$MONITORING_START_DATETIME)),
    MONITORING_END_DATETIME = map_chr(data, ~ max(.x$MONITORING_END_DATETIME)),
    RECORDING_DURATION_SECONDS = map_chr(data, ~ as.character(sum(as.numeric(.x$RECORDING_DURATION_SECONDS))))
  ) |>
  select(-data, -`$file`)

detections <- raw_detections |>
  mutate(
    UNIQUE_ID = str_extract(UNIQUE_ID, "^[^_]+_[^_]+_[^_]+_[^_]+")
  ) |> 
  select(-`$file`)

tabyl(metadata, UNIQUE_ID)
tabyl(detections, UNIQUE_ID)

skimr::skim(detections)
stopifnot(
  all(detections$UNIQUE_ID %in% metadata$UNIQUE_ID)
)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
