detection_row <- function(...) {
  base <- tibble(
    submission_id = "SUB1",
    deployment_code = "D1",
    analysis_organization_code = "SYRACUSE",
    analysis_sound_source_codes = "RIWH",
    analysis_start_datetime = parse_pars_datetime("2025-04-25T00:00:00Z"),
    analysis_end_datetime = parse_pars_datetime("2025-04-30T00:00:00Z"),
    analysis_sample_rate_khz = 2,
    analysis_min_frequency_khz = 0,
    analysis_max_frequency_khz = 1,
    analysis_processing_code = "POST_PROCESSED",
    analysis_protocol_reference = "Davis et al. 2020",
    analysis_citations = NA_character_,
    analysis_detector_code = "LFDCS",
    analysis_detector_version = "1.2",
    detection_start_datetime = parse_pars_datetime("2025-04-25T00:00:00Z"),
    detection_end_datetime = parse_pars_datetime("2025-04-26T00:00:00Z"),
    detection_effort_secs = 86400,
    detection_sound_source_code = "RIWH",
    detection_call_type_code = "RW_UPCALL",
    detection_n_validated = 1L,
    detection_result_code = "DETECTED",
    localization_latitude = NA_real_,
    localization_longitude = NA_real_
  )
  overrides <- list(...)
  for (n in names(overrides)) base[[n]] <- overrides[[n]]
  base
}

analysis_deployments <- function(codes = "D1") {
  tibble(
    organization_code = "SYRACUSE",
    deployment_id = paste0("SYRACUSE:", codes),
    deployment_code = codes,
    recorder_depth_meters = "37",
    instrument_type = "SOUNDTRAP",
    sampling_rate_hz = "48,000"
  )
}

# species expansion ----------------------------------------------------------

test_that("a row naming its species is used as submitted", {
  x <- pars_expand_species(detection_row())

  expect_equal(nrow(x), 1)
  expect_equal(x$species, "RIWH")
})

test_that("a non-detection with no species expands to every analysed species", {
  x <- pars_expand_species(detection_row(
    analysis_sound_source_codes = "RIWH,HUWH,FIWH",
    detection_sound_source_code = NA_character_,
    detection_result_code = "NOT_DETECTED"
  ))

  expect_equal(nrow(x), 3)
  expect_setequal(x$species, c("RIWH", "HUWH", "FIWH"))
})

test_that("expansion fabricates no species beyond those analysed", {
  x <- pars_expand_species(detection_row(
    analysis_sound_source_codes = "RIWH,HUWH",
    detection_sound_source_code = NA_character_,
    detection_result_code = "NOT_DETECTED"
  ))

  expect_setequal(x$species, c("RIWH", "HUWH"))
})

test_that("expansion tolerates spaces in the code list", {
  x <- pars_expand_species(detection_row(
    analysis_sound_source_codes = "RIWH, HUWH",
    detection_sound_source_code = NA_character_,
    detection_result_code = "NOT_DETECTED"
  ))

  expect_setequal(x$species, c("RIWH", "HUWH"))
})

test_that("a detected row is never expanded even in a multi-species analysis", {
  x <- pars_expand_species(detection_row(
    analysis_sound_source_codes = "RIWH,HUWH,FIWH",
    detection_sound_source_code = "RIWH",
    detection_result_code = "DETECTED"
  ))

  expect_equal(nrow(x), 1)
  expect_equal(x$species, "RIWH")
})

test_that("no detection row is dropped during expansion", {
  rows <- bind_rows(
    detection_row(detection_sound_source_code = "RIWH"),
    detection_row(
      detection_sound_source_code = NA_character_,
      detection_result_code = "NOT_DETECTED",
      analysis_sound_source_codes = "RIWH,HUWH"
    )
  )

  x <- pars_expand_species(rows)

  expect_equal(nrow(x), 3)
})

# presence -------------------------------------------------------------------

daily <- function(analyses, species = "RIWH") {
  analyses$detections[[which(analyses$species == species)]]
}

test_that("a detected day is y", {
  a <- pars_analyses_table(detection_row(), analysis_deployments())

  expect_equal(daily(a)$presence, "y")
})

test_that("a not-detected day is n", {
  a <- pars_analyses_table(
    detection_row(detection_result_code = "NOT_DETECTED"),
    analysis_deployments()
  )

  expect_equal(daily(a)$presence, "n")
})

test_that("a possibly-detected day is m", {
  a <- pars_analyses_table(
    detection_row(detection_result_code = "POSSIBLY_DETECTED"),
    analysis_deployments()
  )

  expect_equal(daily(a)$presence, "m")
})

test_that("an unavailable day is na", {
  a <- pars_analyses_table(
    detection_row(detection_result_code = "NOT_AVAILABLE"),
    analysis_deployments()
  )

  expect_equal(daily(a)$presence, "na")
})

test_that("detected wins over possibly and not detected on the same day", {
  rows <- bind_rows(
    detection_row(detection_result_code = "NOT_DETECTED"),
    detection_row(detection_result_code = "POSSIBLY_DETECTED"),
    detection_row(detection_result_code = "DETECTED")
  )

  a <- pars_analyses_table(rows, analysis_deployments())

  expect_equal(nrow(daily(a)), 1)
  expect_equal(daily(a)$presence, "y")
})

test_that("possibly detected wins over not detected on the same day", {
  rows <- bind_rows(
    detection_row(detection_result_code = "NOT_DETECTED"),
    detection_row(detection_result_code = "POSSIBLY_DETECTED")
  )

  a <- pars_analyses_table(rows, analysis_deployments())

  expect_equal(daily(a)$presence, "m")
})

test_that("separate days stay separate", {
  rows <- bind_rows(
    detection_row(),
    detection_row(
      detection_start_datetime = parse_pars_datetime("2025-04-26T00:00:00Z"),
      detection_result_code = "NOT_DETECTED"
    )
  )

  a <- pars_analyses_table(rows, analysis_deployments())

  expect_equal(nrow(daily(a)), 2)
  expect_equal(daily(a)$presence, c("y", "n"))
})

# analysis identity ----------------------------------------------------------

test_that("analysis_id combines deployment and species", {
  a <- pars_analyses_table(detection_row(), analysis_deployments())

  expect_equal(as.character(a$analysis_id), "SYRACUSE:D1:RIWH")
})

test_that("the analysis window covers only days that were actually analysed", {
  # PARS analysis_end_datetime is the EXCLUSIVE end of a half-open interval: a
  # window ending 2025-04-30T00:00 does not include 2025-04-30. Deriving the end
  # date from that field directly made the downstream gap-fill invent a trailing
  # "not detected" day per analysis - fabricated coverage nobody reported.
  a <- pars_analyses_table(detection_row(), analysis_deployments())

  expect_equal(a$analysis_start_date, as.Date("2025-04-25"))
  expect_equal(a$analysis_end_date, as.Date("2025-04-25"))
})

test_that("the analysis window spans first to last analysed day", {
  rows <- bind_rows(
    detection_row(detection_start_datetime = parse_pars_datetime("2025-04-25T00:00:00Z")),
    detection_row(detection_start_datetime = parse_pars_datetime("2025-04-27T00:00:00Z"))
  )

  a <- pars_analyses_table(rows, analysis_deployments())

  expect_equal(a$analysis_start_date, as.Date("2025-04-25"))
  expect_equal(a$analysis_end_date, as.Date("2025-04-27"))
})

test_that("no day beyond the last analysed day enters the window", {
  # analysis_end_datetime is a week past the only detection
  a <- pars_analyses_table(
    detection_row(analysis_end_datetime = parse_pars_datetime("2025-05-02T00:00:00Z")),
    analysis_deployments()
  )

  expect_equal(a$analysis_end_date, as.Date("2025-04-25"))
})

test_that("deployment attributes are joined onto the analysis", {
  a <- pars_analyses_table(detection_row(), analysis_deployments())

  expect_equal(a$deployment_id, "SYRACUSE:D1")
  expect_equal(a$instrument_type, "SOUNDTRAP")
  expect_equal(a$sampling_rate_hz, "48,000")
})

test_that("the analysis sample rate converts kHz to Hz", {
  a <- pars_analyses_table(detection_row(analysis_sample_rate_khz = 2), analysis_deployments())

  expect_equal(a$analysis_sampling_rate_hz, 2000)
})

test_that("the detector code becomes detection_method", {
  a <- pars_analyses_table(detection_row(), analysis_deployments())

  expect_equal(a$detection_method, "LFDCS")
  expect_equal(a$qc_data, "POST_PROCESSED")
})

test_that("call types are aggregated across the analysis", {
  rows <- bind_rows(
    detection_row(detection_call_type_code = "RW_UPCALL"),
    detection_row(
      detection_start_datetime = parse_pars_datetime("2025-04-26T00:00:00Z"),
      detection_call_type_code = "RW_GUNSHOT"
    )
  )

  a <- pars_analyses_table(rows, analysis_deployments())

  expect_true(grepl("RW_UPCALL", a$call_type))
  expect_true(grepl("RW_GUNSHOT", a$call_type))
})

test_that("two species in one analysis become two analyses", {
  rows <- detection_row(
    analysis_sound_source_codes = "RIWH,HUWH",
    detection_sound_source_code = NA_character_,
    detection_result_code = "NOT_DETECTED"
  )

  a <- pars_analyses_table(rows, analysis_deployments())

  expect_equal(nrow(a), 2)
  expect_setequal(a$species, c("RIWH", "HUWH"))
  expect_equal(anyDuplicated(a$analysis_id), 0)
})

test_that("different detectors on one deployment stay separate analyses", {
  rows <- bind_rows(
    detection_row(analysis_detector_code = "LFDCS"),
    detection_row(analysis_detector_code = "MANUAL")
  )

  a <- pars_analyses_table(rows, analysis_deployments())

  expect_equal(nrow(a), 2)
  expect_setequal(a$detection_method, c("LFDCS", "MANUAL"))
})

# locations ------------------------------------------------------------------

test_that("locations stay empty when no localization is submitted", {
  a <- pars_analyses_table(detection_row(), analysis_deployments())

  expect_true(is.null(daily(a)$locations[[1]]))
})

test_that("localization coordinates are nested into locations", {
  a <- pars_analyses_table(
    detection_row(localization_latitude = 41.2, localization_longitude = -70.5),
    analysis_deployments()
  )

  locations <- daily(a)$locations[[1]]

  expect_equal(nrow(locations), 1)
  expect_equal(locations$latitude, 41.2)
  expect_equal(locations$longitude, -70.5)
})

# the plan's hand-built reconciliation fixture --------------------------------

test_that("a three-species analysis with mixed results yields the exact table", {
  # RIWH detected on day 1, possibly on day 2
  # HUWH and FIWH covered by the analysis but never named on non-detection rows
  rows <- bind_rows(
    detection_row(
      analysis_sound_source_codes = "RIWH,HUWH,FIWH",
      detection_sound_source_code = "RIWH",
      detection_result_code = "DETECTED",
      detection_start_datetime = parse_pars_datetime("2025-04-25T00:00:00Z")
    ),
    detection_row(
      analysis_sound_source_codes = "RIWH,HUWH,FIWH",
      detection_sound_source_code = "RIWH",
      detection_result_code = "POSSIBLY_DETECTED",
      detection_start_datetime = parse_pars_datetime("2025-04-26T00:00:00Z")
    ),
    detection_row(
      analysis_sound_source_codes = "RIWH,HUWH,FIWH",
      detection_sound_source_code = NA_character_,
      detection_call_type_code = NA_character_,
      detection_n_validated = NA_integer_,
      detection_result_code = "NOT_DETECTED",
      detection_start_datetime = parse_pars_datetime("2025-04-25T00:00:00Z")
    ),
    detection_row(
      analysis_sound_source_codes = "RIWH,HUWH,FIWH",
      detection_sound_source_code = NA_character_,
      detection_call_type_code = NA_character_,
      detection_n_validated = NA_integer_,
      detection_result_code = "NOT_DETECTED",
      detection_start_datetime = parse_pars_datetime("2025-04-26T00:00:00Z")
    )
  )

  a <- pars_analyses_table(rows, analysis_deployments())

  expect_equal(nrow(a), 3)
  expect_setequal(a$species, c("RIWH", "HUWH", "FIWH"))

  # RIWH: detected day 1 (the non-detection also expands to RIWH but loses)
  expect_equal(daily(a, "RIWH")$presence, c("y", "m"))
  # HUWH and FIWH: covered on both days, never detected
  expect_equal(daily(a, "HUWH")$presence, c("n", "n"))
  expect_equal(daily(a, "FIWH")$presence, c("n", "n"))
})
