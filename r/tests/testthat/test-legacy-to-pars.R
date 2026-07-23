# Legacy PACM_20240820 -> PARS conversion
#
# The converters take *parsed* legacy frames - the schema the legacy loader
# produces, with POSIXct datetimes already resolved to UTC and numeric fields
# numeric. Working from the resolved values (not raw strings) reuses the tested
# timezone handling and keeps conversion output in parity with the legacy data.

legacy_metadata_fixture <- function (...) {
  base <- tibble(
    UNIQUE_ID = "MY_SITE_2024",
    PROJECT = "MY_PROJECT",
    SITE_ID = "SITE_A",
    STATIONARY_OR_MOBILE = "STATIONARY",
    PLATFORM_TYPE = "BOTTOM_MOUNTED_MOORING",
    PLATFORM_ID = "MOORING_7",
    INSTRUMENT_TYPE = "AMAR",
    INSTRUMENT_ID = "AMAR-247",
    CHANNEL = 1,
    MONITORING_START_DATETIME = as.POSIXct("2024-05-21 09:19:00", tz = "UTC"),
    MONITORING_END_DATETIME = as.POSIXct("2024-08-13 15:02:53", tz = "UTC"),
    SOUNDFILES_TIMEZONE = "UTC",
    LATITUDE = 40.58,
    LONGITUDE = -72.58,
    WATER_DEPTH_METERS = 40,
    RECORDER_DEPTH_METERS = 37,
    SAMPLING_RATE_HZ = 48000,
    RECORDING_DURATION_SECONDS = 14400,
    RECORDING_INTERVAL_SECONDS = 14400,
    SAMPLE_BITS = 16,
    DATA_POC_NAME = "Susan Parks",
    DATA_POC_EMAIL = "sparks@syr.edu"
  )
  overrides <- list(...)
  for (n in names(overrides)) base[[n]] <- overrides[[n]]
  base
}

legacy_detectiondata_fixture <- function (...) {
  base <- tibble(
    UNIQUE_ID = "MY_SITE_2024",
    ANALYSIS_PERIOD_START_DATETIME = as.POSIXct("2024-05-21 00:00:00", tz = "UTC"),
    ANALYSIS_PERIOD_END_DATETIME = as.POSIXct("2024-05-22 00:00:00", tz = "UTC"),
    ANALYSIS_PERIOD_EFFORT_SECONDS = "86400",
    ANALYSIS_TIME_ZONE = "UTC",
    SPECIES_CODE = "RIWH",
    ACOUSTIC_PRESENCE = "DETECTED",
    N_VALIDATED_DETECTIONS = "3",
    CALL_TYPE_CODE = "RW_UPCALL",
    DETECTION_METHOD = "Manual",
    PROTOCOL_REFERENCE = "Davis et al. 2020",
    DETECTION_SOFTWARE_NAME = "Raven Pro",
    DETECTION_SOFTWARE_VERSION = "1.6",
    MIN_ANALYSIS_FREQUENCY_RANGE_HZ = "50",
    MAX_ANALYSIS_FREQUENCY_RANGE_HZ = "1000",
    ANALYSIS_SAMPLING_RATE_HZ = "2000",
    QC_PROCESSING = "ARCHIVAL",
    LOCALIZED_LATITUDE = NA_character_,
    LOCALIZED_LONGITUDE = NA_character_,
    DETECTION_DISTANCE_M = NA_character_
  )
  overrides <- list(...)
  for (n in names(overrides)) base[[n]] <- overrides[[n]]
  base
}

legacy_gpsdata_fixture <- function () {
  tibble(
    UNIQUE_ID = "MY_GLIDER_2024",
    DATETIME = as.POSIXct(
      c("2024-05-21 09:19:00", "2024-05-21 10:19:00"), tz = "UTC"
    ),
    LATITUDE = c(40.58, 40.60),
    LONGITUDE = c(-72.58, -72.55)
  )
}

# metadata --------------------------------------------------------------------

test_that("metadata maps to the PARS column set", {
  out <- legacy_to_pars_metadata(
    legacy_metadata_fixture(), organization_code = "SYRACUSE"
  )

  expect_equal(out$deployment_organization_code, "SYRACUSE")
  expect_equal(out$deployment_code, "MY_SITE_2024")
  expect_equal(out$project_name, "MY_PROJECT")
  expect_equal(out$site_code, "SITE_A")
  expect_equal(out$deployment_platform_type_code, "BOTTOM_MOUNTED_MOORING")
  expect_equal(out$recording_device_type_code, "AMAR")
  expect_equal(out$recording_device_code, "AMAR-247")
})

test_that("sampling rate converts Hz to kHz", {
  out <- legacy_to_pars_metadata(
    legacy_metadata_fixture(SAMPLING_RATE_HZ = 48000), "SYRACUSE"
  )

  expect_equal(out$recording_sample_rate_khz, 48)
})

test_that("coordinates keep full precision, not 7 significant figures", {
  out <- legacy_to_pars_metadata(
    legacy_metadata_fixture(LONGITUDE = -71.404253417), "SYRACUSE"
  )

  expect_equal(out$deployment_longitude, -71.404253417)
})

test_that("a UTC datetime is stamped with a zero offset, not left naive", {
  out <- legacy_to_pars_metadata(legacy_metadata_fixture(), "SYRACUSE")

  expect_equal(out$monitoring_start_datetime, "2024-05-21T09:19:00+0000")
  expect_match(out$monitoring_end_datetime, "\\+0000$")
})

test_that("points_of_contact is assembled as Name <email>", {
  out <- legacy_to_pars_metadata(legacy_metadata_fixture(), "SYRACUSE")

  expect_equal(out$points_of_contact, "Susan Parks <sparks@syr.edu>")
})

test_that("project_funding is an explicit parameter, not a silent blank", {
  out <- legacy_to_pars_metadata(
    legacy_metadata_fixture(), "SYRACUSE", project_funding = "ASMFC 25-0108"
  )

  expect_equal(out$project_funding, "ASMFC 25-0108")
})

test_that("platform id is taken from PLATFORM_NO when PLATFORM_ID is absent", {
  # most raw files name this column PLATFORM_NO; a few use PLATFORM_ID. the
  # combined legacy frame hid the difference
  x <- legacy_metadata_fixture()
  x$PLATFORM_ID <- NULL
  x$PLATFORM_NO <- "MOORING_9"

  out <- legacy_to_pars_metadata(x, "SYRACUSE")

  expect_equal(out$deployment_platform_id, "MOORING_9")
})

test_that("metadata converts when the deployment comments column is absent", {
  x <- legacy_metadata_fixture()
  x$PLATFORM_ID <- NULL
  x$PLATFORM_NO <- "MOORING_9"

  expect_no_error(legacy_to_pars_metadata(x, "SYRACUSE"))
})

test_that("metadata output validates under PARS_LEGACY", {
  parsed <- parse_pars_metadata(
    tibble::add_column(
      legacy_to_pars_metadata(legacy_metadata_fixture(), "SYRACUSE"),
      .before = 1, row = 1L
    )
  )

  errors <- validate_pars(parsed, "metadata", test_codes(), "PARS_LEGACY")

  expect_equal(nrow(errors), 0)
})

test_that("metadata output does NOT validate under strict PARS_1.0", {
  # project_funding has no legacy source, so a converted submission is legal
  # only under the relaxed profile
  parsed <- parse_pars_metadata(
    tibble::add_column(
      legacy_to_pars_metadata(legacy_metadata_fixture(), "SYRACUSE"),
      .before = 1, row = 1L
    )
  )

  errors <- validate_pars(parsed, "metadata", test_codes(), "PARS_1.0")

  expect_true(any(grepl("project_funding", errors$name)))
})

# detectiondata ---------------------------------------------------------------

test_that("acoustic presence maps directly to the result code", {
  out <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(ACOUSTIC_PRESENCE = "POSSIBLY_DETECTED"),
    organization_code = "SYRACUSE"
  )

  expect_equal(out$detection_result_code, "POSSIBLY_DETECTED")
})

test_that("QC_PROCESSING normalises ARCHIVAL to POST_PROCESSED", {
  out <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(QC_PROCESSING = "ARCHIVAL"), "SYRACUSE"
  )

  expect_equal(out$analysis_processing_code, "POST_PROCESSED")
})

test_that("QC_PROCESSING normalises the REAL-TIME hyphen to an underscore", {
  out <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(QC_PROCESSING = "REAL-TIME"), "SYRACUSE"
  )

  expect_equal(out$analysis_processing_code, "REAL_TIME")
})

test_that("analysis frequencies convert Hz to kHz", {
  out <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(
      MIN_ANALYSIS_FREQUENCY_RANGE_HZ = "50",
      MAX_ANALYSIS_FREQUENCY_RANGE_HZ = "1000",
      ANALYSIS_SAMPLING_RATE_HZ = "2000"
    ),
    "SYRACUSE"
  )

  expect_equal(out$analysis_min_frequency_khz, 0.05)
  expect_equal(out$analysis_max_frequency_khz, 1)
  expect_equal(out$analysis_sample_rate_khz, 2)
})

test_that("the analysis window is the group min/max, constant across the group", {
  x <- bind_rows(
    legacy_detectiondata_fixture(
      ANALYSIS_PERIOD_START_DATETIME = as.POSIXct("2024-05-21 00:00:00", tz = "UTC"),
      ANALYSIS_PERIOD_END_DATETIME = as.POSIXct("2024-05-22 00:00:00", tz = "UTC")
    ),
    legacy_detectiondata_fixture(
      ANALYSIS_PERIOD_START_DATETIME = as.POSIXct("2024-05-25 00:00:00", tz = "UTC"),
      ANALYSIS_PERIOD_END_DATETIME = as.POSIXct("2024-05-26 00:00:00", tz = "UTC"),
      ACOUSTIC_PRESENCE = "NOT_DETECTED"
    )
  )

  out <- legacy_to_pars_detectiondata(x, "SYRACUSE")

  expect_equal(unique(out$analysis_start_datetime), "2024-05-21T00:00:00+0000")
  expect_equal(unique(out$analysis_end_datetime), "2024-05-26T00:00:00+0000")
})

test_that("every detection stays within its derived analysis window", {
  out <- legacy_to_pars_detectiondata(legacy_detectiondata_fixture(), "SYRACUSE")

  expect_true(all(out$detection_start_datetime >= out$analysis_start_datetime))
  expect_true(all(out$detection_end_datetime <= out$analysis_end_datetime))
})

test_that("detector free text maps to a detectors vocabulary code", {
  jasco <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(
      DETECTION_METHOD = "Manual review of pitch tracks/contours using JASCO's contour and click detectors"
    ),
    "SYRACUSE"
  )
  manual <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(DETECTION_METHOD = "Manual"), "SYRACUSE"
  )
  rps <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(
      DETECTION_METHOD = "Manual review of pitch tracks/contours using RPS contour and click detectors"
    ),
    "SYRACUSE"
  )

  expect_equal(jasco$analysis_detector_code, "JASCO_CONTOUR_CLICK")
  expect_equal(manual$analysis_detector_code, "MANUAL")
  expect_equal(rps$analysis_detector_code, "RPS")
})

test_that("an unrecognised detector maps to the OTHER supplement code", {
  out <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(DETECTION_METHOD = "some bespoke in-house tool"),
    "SYRACUSE"
  )

  expect_equal(out$analysis_detector_code, "OTHER")
})

test_that("known legacy detectors are preserved, not collapsed to OTHER", {
  # detectors with no official PARS code keep their value as a supplement
  # code so published detection_method matches the legacy baseline
  cases <- c(
    "Custom automatic detector" = "AUTOMATIC",
    "Automatic and manual" = "AUTOMATIC/MANUAL",
    "MATLAB-based automated detector algorithm" = "MATLAB",
    "Matched-filter data-template detection algorithm" = "MATCHED_FILTER",
    "GILLESPIE_EDGE" = "GILLESPIE_EDGE",
    "Triton/DFO TWD" = "TRITON/DFO TWD"
  )
  for (raw in names(cases)) {
    out <- legacy_to_pars_detectiondata(
      legacy_detectiondata_fixture(DETECTION_METHOD = raw), "SYRACUSE"
    )
    expect_equal(out$analysis_detector_code, cases[[raw]], info = raw)
  }
})

test_that("invalid-UTF8 detector text is repaired rather than crashing", {
  corrupt <- legacy_detectiondata_fixture(
    DETECTION_METHOD = "JASCO\x9as contour and click detectors"
  )

  expect_no_error(legacy_to_pars_detectiondata(corrupt, "SYRACUSE"))

  out <- legacy_to_pars_detectiondata(corrupt, "SYRACUSE")
  expect_equal(out$analysis_detector_code, "JASCO_CONTOUR_CLICK")
})

test_that("call type abbreviations remap to vocabulary codes", {
  nbhf <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(CALL_TYPE_CODE = "NBHF"), "SYRACUSE"
  )
  bl <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(CALL_TYPE_CODE = "BLARCH,BLSONG"), "SYRACUSE"
  )

  expect_equal(nbhf$detection_call_type_code, "OD_CLICK_NBHF")
  expect_equal(bl$detection_call_type_code, "BLWH_ARCHD,BLWH_SONG")
})

test_that("call type list order is preserved, not sorted", {
  out <- legacy_to_pars_detectiondata(
    legacy_detectiondata_fixture(CALL_TYPE_CODE = "OD_WHIS,OD_CLICK"), "SYRACUSE"
  )

  expect_equal(out$detection_call_type_code, "OD_WHIS,OD_CLICK")
})

test_that("a submission missing the localization columns still converts", {
  # some raw detectiondata files omit localization entirely; the combined
  # legacy frame hid this because bind_rows unions columns
  x <- legacy_detectiondata_fixture()
  x$LOCALIZED_LATITUDE <- NULL
  x$LOCALIZED_LONGITUDE <- NULL
  x$DETECTION_DISTANCE_M <- NULL

  expect_no_error(legacy_to_pars_detectiondata(x, "SYRACUSE"))

  out <- legacy_to_pars_detectiondata(x, "SYRACUSE")
  expect_true(all(is.na(out$localization_latitude)))
  expect_true(all(is.na(out$localization_distance_m)))
})

test_that("detectiondata output validates under PARS_LEGACY", {
  parsed <- parse_pars_detectiondata(
    tibble::add_column(
      legacy_to_pars_detectiondata(legacy_detectiondata_fixture(), "SYRACUSE"),
      .before = 1, row = 1L
    )
  )

  errors <- validate_pars(parsed, "detectiondata", test_codes(), "PARS_LEGACY")

  expect_equal(nrow(errors), 0)
})

test_that("a detected row with no validated count validates under PARS_LEGACY", {
  parsed <- parse_pars_detectiondata(
    tibble::add_column(
      legacy_to_pars_detectiondata(
        legacy_detectiondata_fixture(N_VALIDATED_DETECTIONS = NA_character_),
        "SYRACUSE"
      ),
      .before = 1, row = 1L
    )
  )

  errors <- validate_pars(parsed, "detectiondata", test_codes(), "PARS_LEGACY")

  expect_equal(nrow(errors), 0)
})

# gpsdata ---------------------------------------------------------------------

test_that("gpsdata maps to the four PARS columns", {
  out <- legacy_to_pars_gpsdata(legacy_gpsdata_fixture())

  expect_equal(names(out), c("deployment_code", "datetime", "latitude", "longitude"))
  expect_equal(out$deployment_code, rep("MY_GLIDER_2024", 2))
  expect_equal(out$datetime[[1]], "2024-05-21T09:19:00+0000")
})

test_that("gpsdata output validates under PARS_LEGACY", {
  parsed <- parse_pars_gpsdata(
    tibble::add_column(
      legacy_to_pars_gpsdata(legacy_gpsdata_fixture()), .before = 1, row = 1L
    )
  )

  errors <- validate_pars(parsed, "gpsdata", test_codes(), "PARS_LEGACY")

  expect_equal(nrow(errors), 0)
})

# convert_legacy_submission ---------------------------------------------------
#
# convert_legacy_submission takes *raw* legacy frames (character columns, string
# datetimes - the shape a submission's clean/*.csv holds) and runs the full
# clean -> parse -> legacy_to_pars chain, writing PARS files to dir/clean/.

legacy_metadata_raw_fixture <- function (...) {
  base <- tibble(
    UNIQUE_ID = "MY_SITE_2024",
    PROJECT = "MY_PROJECT",
    SITE_ID = "SITE_A",
    STATIONARY_OR_MOBILE = "Stationary",
    PLATFORM_TYPE = "BOTTOM_MOUNTED_MOORING",
    PLATFORM_NO = "MOORING_7",
    INSTRUMENT_TYPE = "AMAR",
    INSTRUMENT_ID = "AMAR-247",
    CHANNEL = "1",
    MONITORING_START_DATETIME = "2024-05-21 09:19:00",
    MONITORING_END_DATETIME = "2024-08-13 15:02:53",
    SOUNDFILES_TIMEZONE = "UTC",
    LATITUDE = "40.58",
    LONGITUDE = "-72.58",
    WATER_DEPTH_METERS = "40",
    RECORDER_DEPTH_METERS = "37",
    SAMPLING_RATE_HZ = "48000",
    RECORDING_DURATION_SECONDS = "14400",
    RECORDING_INTERVAL_SECONDS = "14400",
    SAMPLE_BITS = "16",
    DATA_POC_NAME = "Susan Parks",
    DATA_POC_EMAIL = "sparks@syr.edu"
  )
  overrides <- list(...)
  for (n in names(overrides)) base[[n]] <- overrides[[n]]
  base
}

test_that("a metadata-only submission writes metadata but no detectiondata", {
  # DFOCA_20220712 deploys recorders whose detections another submission holds;
  # convert must accept detectiondata = NULL and emit only metadata.csv
  dir <- withr::local_tempdir()

  convert_legacy_submission(
    dir,
    metadata = legacy_metadata_raw_fixture(),
    detectiondata = NULL,
    organization_code = "DFO"
  )

  expect_true(file.exists(file.path(dir, "clean", "metadata.csv")))
  expect_false(file.exists(file.path(dir, "clean", "detectiondata.csv")))
})

test_that("convert normalises typed input columns (numeric, POSIXct)", {
  # a submission's clean.R may hand over typed frames (RECORDING_DURATION_SECONDS
  # as a number, datetimes as POSIXct) rather than the all-character shape a
  # clean/*.csv holds; convert must coerce so parse_number et al. don't choke
  dir <- withr::local_tempdir()

  typed <- legacy_metadata_raw_fixture(
    RECORDING_DURATION_SECONDS = 14400,
    MONITORING_START_DATETIME = as.POSIXct("2024-05-21 09:19:00", tz = "UTC")
  )

  expect_no_error(
    convert_legacy_submission(
      dir, metadata = typed, detectiondata = NULL, organization_code = "DFO"
    )
  )
})

test_that("convert writes both metadata and detectiondata when given detections", {
  dir <- withr::local_tempdir()

  convert_legacy_submission(
    dir,
    metadata = legacy_metadata_raw_fixture(),
    detectiondata = tibble::tibble(
      UNIQUE_ID = "MY_SITE_2024",
      ANALYSIS_PERIOD_START_DATETIME = "2024-05-21 00:00:00",
      ANALYSIS_PERIOD_END_DATETIME = "2024-05-22 00:00:00",
      ANALYSIS_PERIOD_EFFORT_SECONDS = "86400",
      ANALYSIS_TIME_ZONE = "UTC",
      SPECIES = "RIWH",
      CALL_TYPE = "UPCALL",
      QC_PROCESSING = "ARCHIVAL",
      ACOUSTIC_PRESENCE = "Y",
      DETECTION_METHOD = "Manual"
    ),
    organization_code = "DFO"
  )

  expect_true(file.exists(file.path(dir, "clean", "metadata.csv")))
  expect_true(file.exists(file.path(dir, "clean", "detectiondata.csv")))
})

test_that("a detections-only submission writes detectiondata but no metadata", {
  # the DFOCA LF sei-whale submissions carry detections whose deployments another
  # submission provided; convert must accept metadata = NULL and emit only
  # detectiondata.csv, letting global referential integrity resolve the deployment
  dir <- withr::local_tempdir()

  convert_legacy_submission(
    dir,
    metadata = NULL,
    detectiondata = tibble::tibble(
      UNIQUE_ID = "EMBD_2015_05_LF",
      ANALYSIS_PERIOD_START_DATETIME = "2015-05-24 00:00:00",
      ANALYSIS_PERIOD_END_DATETIME = "2015-05-25 00:00:00",
      ANALYSIS_PERIOD_EFFORT_SECONDS = "86400",
      ANALYSIS_TIME_ZONE = "UTC",
      SPECIES = "SEWH",
      CALL_TYPE = "SWDS",
      QC_PROCESSING = "Archival",
      ACOUSTIC_PRESENCE = "D",
      DETECTION_METHOD = "JASCO AA"
    ),
    organization_code = "DFO"
  )

  expect_false(file.exists(file.path(dir, "clean", "metadata.csv")))
  expect_true(file.exists(file.path(dir, "clean", "detectiondata.csv")))

  out <- readr::read_csv(
    file.path(dir, "clean", "detectiondata.csv"), show_col_types = FALSE
  )
  expect_equal(out$deployment_code, "EMBD_2015_05_LF")
  expect_equal(out$detection_sound_source_code, "SEWH")
  expect_equal(out$detection_call_type_code, "SEWH_DS80HZ")
})
