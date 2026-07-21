
transform_metadata <- function (raw) {
  raw |> 
    nest(
      data = c(row, INSTRUMENT_ID, MONITORING_START_DATETIME, MONITORING_END_DATETIME, RECORDING_DURATION_SECONDS)
    ) |> 
    mutate(
      row = map_int(data, ~ min(.x$row)),
      INSTRUMENT_ID = map_chr(data, ~ str_c(unique(.x$INSTRUMENT_ID), collapse = ",")),
      MONITORING_START_DATETIME = map_chr(data, ~ min(.x$MONITORING_START_DATETIME)),
      MONITORING_END_DATETIME = map_chr(data, ~ max(.x$MONITORING_END_DATETIME)),
      RECORDING_DURATION_SECONDS = map_chr(data, ~ as.character(sum(as.numeric(.x$RECORDING_DURATION_SECONDS))))
    ) |> 
    select(-data)
}

transform_detectiondata <- function (raw) {
  raw |> 
    mutate(
      # Extract first part of UNIQUE_ID before the date/time, species, call
      # RPS_EastUS_20240809_B5_B5P1_20240809-1530_BLWH_BLMIX -> RPS_EastUS_20240809_B5_B5P1
      UNIQUE_ID = str_extract(UNIQUE_ID, "^[^_]+_[^_]+_[^_]+_[^_]+_[^_]+")
    )
}
