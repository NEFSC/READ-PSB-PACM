# the I-1 acceptance test -----------------------------------------------------

test_that("a sample rate submitted in Hz is caught by the plausibility range", {
  # this is exactly the USYRA_20260713 error: 48000 in a kHz field
  x <- valid_metadata(recording_sample_rate_khz = 48000)

  errors <- validate_pars(x, "metadata", test_codes())

  expect_true(any(grepl("recording_sample_rate_khz", errors$name)))
})

test_that("a plausible sample rate passes", {
  x <- valid_metadata(recording_sample_rate_khz = 48)

  expect_equal(nrow(validate_pars(x, "metadata", test_codes())), 0)
})

# baseline --------------------------------------------------------------------

test_that("valid metadata produces no errors", {
  expect_equal(nrow(validate_pars(valid_metadata(), "metadata", test_codes())), 0)
})

test_that("valid detectiondata produces no errors", {
  x <- valid_detectiondata()

  expect_equal(nrow(validate_pars(x, "detectiondata", test_codes())), 0)
})

# presence --------------------------------------------------------------------

test_that("a missing required field is reported", {
  x <- valid_metadata(site_code = NA_character_)

  errors <- validate_pars(x, "metadata", test_codes())

  expect_true(any(grepl("site_code", errors$name)))
})

test_that("a naive timestamp surfaces as a missing datetime", {
  x <- valid_metadata(
    monitoring_start_datetime = parse_pars_datetime("2025-04-24T17:29:04")
  )

  errors <- validate_pars(x, "metadata", test_codes())

  expect_true(any(grepl("monitoring_start_datetime", errors$name)))
})

# vocabulary ------------------------------------------------------------------

test_that("an unknown platform type is reported", {
  x <- valid_metadata(deployment_platform_type_code = "SPACE_STATION")

  errors <- validate_pars(x, "metadata", test_codes())

  expect_true(any(grepl("deployment_platform_type_code", errors$name)))
})

test_that("an unknown detector code is reported", {
  x <- valid_detectiondata(analysis_detector_code = "NOT_A_DETECTOR")

  errors <- validate_pars(x, "detectiondata", test_codes())

  expect_true(any(grepl("analysis_detector_code", errors$name)))
})

# ranges ----------------------------------------------------------------------

test_that("an out-of-range latitude is reported", {
  x <- valid_metadata(deployment_latitude = 200)

  errors <- validate_pars(x, "metadata", test_codes())

  expect_true(any(grepl("deployment_latitude", errors$name)))
})

test_that("a negative water depth is reported", {
  x <- valid_metadata(deployment_water_depth_m = -5)

  errors <- validate_pars(x, "metadata", test_codes())

  expect_true(any(grepl("deployment_water_depth_m", errors$name)))
})

test_that("monitoring end before start is reported", {
  x <- valid_metadata(
    monitoring_end_datetime = parse_pars_datetime("2020-01-01T00:00:00Z")
  )

  errors <- validate_pars(x, "metadata", test_codes())

  expect_true(any(grepl("monitoring", errors$name)))
})

# conditional requirements ----------------------------------------------------

test_that("a DETECTED row without a species is reported", {
  x <- valid_detectiondata(detection_sound_source_code = NA_character_)

  errors <- validate_pars(x, "detectiondata", test_codes())

  expect_true(any(grepl("detection_sound_source_code", errors$name)))
})

test_that("a NOT_DETECTED row may omit the species", {
  x <- valid_detectiondata(
    detection_result_code = "NOT_DETECTED",
    detection_sound_source_code = NA_character_,
    detection_call_type_code = NA_character_,
    detection_n_validated = NA_integer_
  )

  expect_equal(nrow(validate_pars(x, "detectiondata", test_codes())), 0)
})

# profiles --------------------------------------------------------------------

test_that("PARS_1.0 requires project_funding", {
  x <- valid_metadata(project_funding = NA_character_)

  errors <- validate_pars(x, "metadata", test_codes(), profile = "PARS_1.0")

  expect_true(any(grepl("project_funding", errors$name)))
})

test_that("PARS_LEGACY allows project_funding to be absent", {
  x <- valid_metadata(project_funding = NA_character_)

  errors <- validate_pars(x, "metadata", test_codes(), profile = "PARS_LEGACY")

  expect_equal(nrow(errors), 0)
})

test_that("PARS_LEGACY allows analysis_detector_version to be absent", {
  x <- valid_detectiondata(analysis_detector_version = NA_character_)

  errors <- validate_pars(x, "detectiondata", test_codes(), profile = "PARS_LEGACY")

  expect_equal(nrow(errors), 0)
})

test_that("PARS_1.0 rejects a comma-separated call type", {
  x <- valid_detectiondata(detection_call_type_code = "RW_UPCALL,HUWH_SONG")

  errors <- validate_pars(x, "detectiondata", test_codes(), profile = "PARS_1.0")

  expect_true(any(grepl("detection_call_type_code", errors$name)))
})

test_that("PARS_LEGACY accepts a comma-separated call type of valid codes", {
  x <- valid_detectiondata(detection_call_type_code = "RW_UPCALL,HUWH_SONG")

  errors <- validate_pars(x, "detectiondata", test_codes(), profile = "PARS_LEGACY")

  expect_equal(nrow(errors), 0)
})

test_that("PARS_LEGACY still rejects an invalid code inside a list", {
  x <- valid_detectiondata(detection_call_type_code = "RW_UPCALL,NOT_A_CALL")

  errors <- validate_pars(x, "detectiondata", test_codes(), profile = "PARS_LEGACY")

  expect_true(any(grepl("detection_call_type_code", errors$name)))
})

# AD-10: the profile must never weaken a check that catches corruption --------

test_that("PARS_LEGACY does not relax the sample rate range", {
  x <- valid_metadata(recording_sample_rate_khz = 48000)

  errors <- validate_pars(x, "metadata", test_codes(), profile = "PARS_LEGACY")

  expect_true(any(grepl("recording_sample_rate_khz", errors$name)))
})

test_that("PARS_LEGACY does not relax vocabulary checks", {
  x <- valid_metadata(deployment_platform_type_code = "SPACE_STATION")

  errors <- validate_pars(x, "metadata", test_codes(), profile = "PARS_LEGACY")

  expect_true(any(grepl("deployment_platform_type_code", errors$name)))
})

test_that("PARS_LEGACY does not relax coordinate ranges", {
  x <- valid_metadata(deployment_latitude = 200)

  errors <- validate_pars(x, "metadata", test_codes(), profile = "PARS_LEGACY")

  expect_true(any(grepl("deployment_latitude", errors$name)))
})

test_that("an unknown profile is rejected", {
  expect_error(
    validate_pars(valid_metadata(), "metadata", test_codes(), profile = "MADE_UP"),
    "profile"
  )
})

# gpsdata ---------------------------------------------------------------------

test_that("valid gpsdata produces no errors", {
  x <- tibble(
    row = 1L,
    deployment_code = "D1",
    datetime = parse_pars_datetime("2025-04-25T00:00:00Z"),
    latitude = 41.5,
    longitude = -70.2
  )

  expect_equal(nrow(validate_pars(x, "gpsdata", test_codes())), 0)
})

test_that("an out-of-range gps longitude is reported", {
  x <- tibble(
    row = 1L,
    deployment_code = "D1",
    datetime = parse_pars_datetime("2025-04-25T00:00:00Z"),
    latitude = 41.5,
    longitude = -400
  )

  errors <- validate_pars(x, "gpsdata", test_codes())

  expect_true(any(grepl("longitude", errors$name)))
})

# error shape -----------------------------------------------------------------

test_that("errors identify the offending row", {
  x <- bind_rows(
    valid_metadata(),
    valid_metadata(row = 2L, deployment_code = "D2", deployment_latitude = 999)
  )

  errors <- validate_pars(x, "metadata", test_codes())

  expect_true(all(errors$row == 2))
})

# rules must never be silently skipped ----------------------------------------

test_that("validating omits no rules and emits no warnings", {
  # `validate` drops rules that reference absent columns with only a warning,
  # which would leave checks silently not running
  expect_no_warning(validate_pars(valid_detectiondata(), "detectiondata", test_codes()))
  expect_no_warning(validate_pars(valid_metadata(), "metadata", test_codes()))
})

test_that("a rule for an absent optional column is skipped, not errored", {
  x <- valid_detectiondata()
  expect_false("localization_latitude" %in% names(x))

  expect_equal(nrow(validate_pars(x, "detectiondata", test_codes())), 0)
})

test_that("an absent optional column is still checked when present", {
  x <- valid_detectiondata()
  x$localization_latitude <- 999

  errors <- validate_pars(x, "detectiondata", test_codes())

  expect_true(any(grepl("localization_latitude", errors$name)))
})

test_that("a required column missing from the file is reported", {
  x <- valid_metadata()
  x$site_code <- NULL

  errors <- validate_pars(x, "metadata", test_codes())

  expect_true(any(grepl("site_code", errors$name)))
})

test_that("a required column missing under PARS_LEGACY relaxation is not reported", {
  x <- valid_metadata()
  x$project_funding <- NULL

  errors <- validate_pars(x, "metadata", test_codes(), profile = "PARS_LEGACY")

  expect_equal(nrow(errors), 0)
})

# the analysis window bounds its detections --------------------------------

test_that("a detection starting before the analysis window is reported", {
  x <- valid_detectiondata(
    detection_start_datetime = parse_pars_datetime("2025-04-01T00:00:00Z")
  )

  errors <- validate_pars(x, "detectiondata", test_codes())

  expect_true(any(grepl("detection_within_analysis_start", errors$name)))
})

test_that("a detection ending after the analysis window is reported", {
  x <- valid_detectiondata(
    detection_end_datetime = parse_pars_datetime("2026-01-01T00:00:00Z")
  )

  errors <- validate_pars(x, "detectiondata", test_codes())

  expect_true(any(grepl("detection_within_analysis_end", errors$name)))
})

test_that("a detection filling the whole window is accepted", {
  x <- valid_detectiondata(
    detection_start_datetime = parse_pars_datetime("2025-04-25T00:00:00Z"),
    detection_end_datetime = parse_pars_datetime("2025-08-13T00:00:00Z")
  )

  expect_equal(nrow(validate_pars(x, "detectiondata", test_codes())), 0)
})
