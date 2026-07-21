suppressMessages({
  library(tibble)
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
