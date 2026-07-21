# PARS type parsing
#
# every PARS field arrives as a character string (read_raw_file reads all
# columns as character) and is coerced here. the guiding rule is that a value
# which cannot be parsed becomes NA rather than a silent approximation - the
# validation rules in pars-validate.R then turn that NA into a row-level error.

# values PARS forbids as stand-ins for "absent"; blank is the only valid way to
# say a value is missing
PARS_PLACEHOLDERS <- c("NA", "N/A", "NULL", "-")

blank_to_na <- function (x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  x
}

# PARS requires a timezone offset on every timestamp. both the colon form
# (-04:00, as USYRA submits) and the compact form (-0400, as the guide's
# examples show) are accepted; a timestamp with no offset parses to NA rather
# than being silently assumed UTC, because guessing a timezone silently shifts
# detections across day boundaries.
parse_pars_datetime <- function (x) {
  x <- blank_to_na(x)

  normalized <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", x)
  normalized <- sub("Z$", "+0000", normalized)
  normalized <- sub(" ", "T", normalized)

  has_offset <- grepl("[+-][0-9]{4}$", normalized)
  normalized[!has_offset] <- NA_character_

  as.POSIXct(normalized, format = "%Y-%m-%dT%H:%M:%S%z", tz = "UTC")
}

parse_pars_number <- function (x) {
  suppressWarnings(as.numeric(blank_to_na(x)))
}

parse_pars_integer <- function (x) {
  suppressWarnings(as.integer(blank_to_na(x)))
}

parse_pars_boolean <- function (x) {
  x <- toupper(blank_to_na(x))
  out <- rep(NA, length(x))
  out[x == "TRUE"] <- TRUE
  out[x == "FALSE"] <- FALSE
  out
}

# report cells holding a forbidden placeholder. this runs on the raw strings,
# before parsing, because once "NA" is coerced it is indistinguishable from a
# legitimately blank cell - and for an optional field that difference is the
# difference between a typo and a valid submission.
pars_placeholder_errors <- function (raw) {
  columns <- setdiff(names(raw), "row")

  errors <- lapply(columns, function (column) {
    # the offending string is returned as `actual`, not `value`: error frames
    # use `value` for the pass/fail flag, and the collision silently shadows
    submitted <- trimws(as.character(raw[[column]]))
    hit <- !is.na(submitted) & toupper(submitted) %in% PARS_PLACEHOLDERS
    tibble::tibble(
      row = raw$row[hit],
      column = column,
      actual = submitted[hit]
    )
  })

  dplyr::bind_rows(errors)
}

# apply a parser to the named columns, skipping any the submission omits
parse_columns <- function (x, columns, parser) {
  present <- intersect(columns, names(x))
  for (column in present) {
    x[[column]] <- parser(x[[column]])
  }
  x
}

PARS_METADATA_DATETIMES <- c(
  "monitoring_start_datetime", "monitoring_end_datetime"
)
PARS_METADATA_NUMBERS <- c(
  "deployment_latitude", "deployment_longitude", "deployment_water_depth_m",
  "recording_device_depth_m", "recording_duration_secs",
  "recording_interval_secs", "recording_sample_rate_khz"
)
PARS_METADATA_INTEGERS <- c("recording_bit_depth", "recording_n_channels")
PARS_METADATA_BOOLEANS <- c("dynamic_management_platform")

parse_pars_metadata <- function (x) {
  x |>
    parse_columns(PARS_METADATA_DATETIMES, parse_pars_datetime) |>
    parse_columns(PARS_METADATA_NUMBERS, parse_pars_number) |>
    parse_columns(PARS_METADATA_INTEGERS, parse_pars_integer) |>
    parse_columns(PARS_METADATA_BOOLEANS, parse_pars_boolean)
}

PARS_DETECTIONDATA_DATETIMES <- c(
  "analysis_start_datetime", "analysis_end_datetime",
  "detection_start_datetime", "detection_end_datetime"
)
PARS_DETECTIONDATA_NUMBERS <- c(
  "analysis_sample_rate_khz", "analysis_min_frequency_khz",
  "analysis_max_frequency_khz", "detection_effort_secs",
  "localization_latitude", "localization_longitude", "localization_distance_m"
)
PARS_DETECTIONDATA_INTEGERS <- c("detection_n_validated")

parse_pars_detectiondata <- function (x) {
  x |>
    parse_columns(PARS_DETECTIONDATA_DATETIMES, parse_pars_datetime) |>
    parse_columns(PARS_DETECTIONDATA_NUMBERS, parse_pars_number) |>
    parse_columns(PARS_DETECTIONDATA_INTEGERS, parse_pars_integer)
}

PARS_GPSDATA_DATETIMES <- c("datetime")
PARS_GPSDATA_NUMBERS <- c("latitude", "longitude")

parse_pars_gpsdata <- function (x) {
  x |>
    parse_columns(PARS_GPSDATA_DATETIMES, parse_pars_datetime) |>
    parse_columns(PARS_GPSDATA_NUMBERS, parse_pars_number)
}
