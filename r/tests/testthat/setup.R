suppressMessages({
  library(tibble)
  library(readr)
  library(stringr)
  library(dplyr)
  # sourced R/ files define targets at the top level, so the test session needs
  # the same packages attached that _targets.R attaches
  library(targets)
  library(tarchetypes)
  library(logger)
  library(tidyr)
  library(purrr)
  library(glue)
  library(lubridate)
  library(sf)
  library(validate)
  library(janitor)
})

source(file.path("..", "..", "R", "functions.R"))
source(file.path("..", "..", "R", "compare.R"))
source(file.path("..", "..", "R", "pars-ref.R"))
source(file.path("..", "..", "R", "pars-parse.R"))
source(file.path("..", "..", "R", "pars-validate.R"))
source(file.path("..", "..", "R", "pars-load.R"))
source(file.path("..", "..", "R", "export.R"))

# reference-code fixtures ----------------------------------------------------

fixture_code_snapshot <- function() {
  list(
    pars_template_version = "1.0",
    tables = list(
      detection_result_types = c("DETECTED", "NOT_DETECTED"),
      detectors = c("LFDCS", "PAMGUARD_CLICK")
    )
  )
}

fixture_supplement <- function(...) {
  rows <- list(...)
  if (length(rows) == 0) {
    return(tibble(
      table = character(), code = character(), label = character(),
      rationale = character(), date_added = character()
    ))
  }
  bind_rows(rows)
}

supplement_row <- function(table, code, label = "Label",
                           rationale = "legacy value with no official code",
                           date_added = "2026-07-21") {
  tibble(
    table = table, code = code, label = label,
    rationale = rationale, date_added = date_added
  )
}

# minimal snapshot fixtures --------------------------------------------------

fixture_deployments <- function() {
  tibble(
    deployment_id = c("ORG:DEP1", "ORG:DEP2"),
    site_id = c("ORG:SITE1", "ORG:SITE2"),
    latitude = c(41.5, 42.0),
    sampling_rate_hz = c(48000, 96000),
    platform_type = c("BOTTOM_MOUNTED_MOORING", "ELECTRIC_GLIDER")
  )
}

fixture_analyses <- function() {
  tibble(
    analysis_id = c("ORG:DEP1:RIWH", "ORG:DEP2:RIWH"),
    deployment_id = c("ORG:DEP1", "ORG:DEP2"),
    species = c("RIWH", "RIWH"),
    detections = list(
      tibble(date = as.Date(c("2025-01-01", "2025-01-02")), presence = c("y", "n")),
      tibble(date = as.Date("2025-02-01"), presence = "m")
    )
  )
}

fixture_multispecies_analyses <- function() {
  tibble(
    analysis_id = rep("ORG:DEP1:ANALYSIS", 2),
    species = c("RIWH", "FIWH"),
    call_type = c("RW_UPCALL", NA_character_),
    detections = list(
      tibble(date = as.Date("2025-01-01"), presence = "y"),
      tibble(date = as.Date("2025-01-01"), presence = "n")
    )
  )
}

fixture_tracks <- function(shift = 0) {
  coords <- matrix(c(-70, 41, -70.5 + shift, 41.5), ncol = 2, byrow = TRUE)
  geometry <- sf::st_sfc(sf::st_linestring(coords), crs = 4326)
  # tibble-backed, matching the real pacm_data$tracks shape
  # (sf/tbl_df/tbl/data.frame)
  sf::st_as_sf(tibble(
    track_id = "ORG:DEP1:TRACK",
    deployment_id = "ORG:DEP1",
    geometry = geometry
  ))
}

fixture_snapshot <- function() {
  list(
    deployments = fixture_deployments(),
    analyses = fixture_analyses()
  )
}

# PARS fixtures --------------------------------------------------------------

test_codes <- function() {
  list(
    organizations = c("SYRACUSE", "NEFSC"),
    platform_types = c("BOTTOM_MOUNTED_MOORING", "ELECTRIC_GLIDER"),
    device_types = c("SOUNDTRAP", "AMAR"),
    detectors = c(
      "LFDCS", "MANUAL", "OTHER", "JASCO_CONTOUR_CLICK", "JASCO_PAMLAB", "RPS",
      "CHORUS_BIOSOUND"
    ),
    analysis_processing_types = c("POST_PROCESSED", "REAL_TIME"),
    detection_result_types = c(
      "DETECTED", "POSSIBLY_DETECTED", "NOT_DETECTED", "NOT_AVAILABLE"
    ),
    sound_sources = c("RIWH", "HUWH"),
    call_types = c(
      "RW_UPCALL", "HUWH_SONG", "OD_CLICK_NBHF", "BLWH_ARCHD", "BLWH_SONG",
      "OD_WHIS", "OD_CLICK"
    )
  )
}

valid_metadata <- function(...) {
  base <- tibble(
    row = 1L,
    deployment_organization_code = "SYRACUSE",
    deployment_code = "SYRACUSE_LI01",
    project_name = "SYRACUSE_NYNJB_LI",
    site_code = "LI01",
    monitoring_start_datetime = parse_pars_datetime("2025-04-24T17:29:04Z"),
    monitoring_end_datetime = parse_pars_datetime("2025-08-13T15:02:53Z"),
    deployment_latitude = 40.58,
    deployment_longitude = -72.58,
    deployment_platform_type_code = "BOTTOM_MOUNTED_MOORING",
    deployment_water_depth_m = 40,
    recording_device_depth_m = 37,
    recording_device_code = "SOUNDTRAP-8541",
    recording_device_type_code = "SOUNDTRAP",
    recording_duration_secs = 14400,
    recording_interval_secs = 14400,
    recording_sample_rate_khz = 48,
    recording_bit_depth = 16L,
    recording_n_channels = 1L,
    recording_timezone = "UTC",
    points_of_contact = "Susan Parks <sparks@syr.edu>",
    project_funding = "ASMFC 25-0108"
  )
  overrides <- list(...)
  for (n in names(overrides)) base[[n]] <- overrides[[n]]
  base
}

valid_detectiondata <- function(...) {
  base <- tibble(
    row = 1L,
    deployment_code = "SYRACUSE_LI01",
    analysis_organization_code = "SYRACUSE",
    analysis_sound_source_codes = "RIWH",
    analysis_start_datetime = parse_pars_datetime("2025-04-25T00:00:00Z"),
    analysis_end_datetime = parse_pars_datetime("2025-08-13T00:00:00Z"),
    analysis_sample_rate_khz = 2,
    analysis_min_frequency_khz = 0,
    analysis_max_frequency_khz = 1,
    analysis_processing_code = "POST_PROCESSED",
    analysis_protocol_reference = "Davis et al. 2020",
    analysis_detector_code = "LFDCS",
    analysis_detector_version = "1.2",
    detection_start_datetime = parse_pars_datetime("2025-04-25T00:00:00Z"),
    detection_end_datetime = parse_pars_datetime("2025-04-26T00:00:00Z"),
    detection_effort_secs = 86400,
    detection_sound_source_code = "RIWH",
    detection_call_type_code = "RW_UPCALL",
    detection_n_validated = 3L,
    detection_result_code = "DETECTED"
  )
  overrides <- list(...)
  for (n in names(overrides)) base[[n]] <- overrides[[n]]
  base
}
