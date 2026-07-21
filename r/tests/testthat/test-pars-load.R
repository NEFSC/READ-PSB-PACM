# profile selection ----------------------------------------------------------

test_that("a versioned PARS format selects the strict profile", {
  expect_equal(pars_profile_for_format("PARS_1.0"), "PARS_1.0")
})

test_that("the legacy format selects the relaxed profile", {
  expect_equal(pars_profile_for_format("PARS_LEGACY"), "PARS_LEGACY")
})

test_that("an unrecognised format is rejected rather than defaulting", {
  expect_error(
    pars_profile_for_format("PACM_20240820"),
    "unsupported PARS submission format"
  )
})

# referential integrity ------------------------------------------------------

ref_metadata <- function(codes = c("D1", "D2")) {
  tibble(row = seq_along(codes), deployment_code = codes)
}

ref_detectiondata <- function(codes = c("D1", "D2")) {
  tibble(row = seq_along(codes), deployment_code = codes)
}

test_that("matching deployment codes produce no referential errors", {
  errors <- pars_referential_errors(ref_metadata(), ref_detectiondata(), NULL)

  expect_equal(nrow(errors), 0)
})

test_that("a detectiondata code absent from metadata is reported", {
  errors <- pars_referential_errors(
    ref_metadata(c("D1")),
    ref_detectiondata(c("D1", "GHOST")),
    NULL
  )

  expect_equal(nrow(errors), 1)
  expect_true(grepl("GHOST", errors$actual))
  expect_equal(errors$row, 2)
})

test_that("a gpsdata code absent from metadata is reported", {
  gps <- tibble(row = 1L, deployment_code = "GHOST")

  errors <- pars_referential_errors(ref_metadata(), ref_detectiondata(), gps)

  expect_equal(nrow(errors), 1)
  expect_true(grepl("gpsdata", errors$name))
})

test_that("a duplicated deployment_code in metadata is reported", {
  errors <- pars_referential_errors(
    ref_metadata(c("D1", "D1")),
    ref_detectiondata(c("D1")),
    NULL
  )

  expect_true(any(grepl("unique", errors$name)))
})

test_that("absent gpsdata is not a referential error", {
  expect_equal(nrow(pars_referential_errors(ref_metadata(), ref_detectiondata(), NULL)), 0)
})

# gpsdata expectations -------------------------------------------------------

platform_metadata <- function(platform, code = "D1") {
  tibble(row = 1L, deployment_code = code, deployment_platform_type_code = platform)
}

test_that("a mobile deployment without gpsdata is an error", {
  errors <- pars_gpsdata_errors(platform_metadata("ELECTRIC_GLIDER"), NULL)

  expect_equal(nrow(errors), 1)
  expect_true(grepl("gpsdata", errors$name))
})

test_that("a mobile deployment with gpsdata is fine", {
  gps <- tibble(row = 1L, deployment_code = "D1")

  errors <- pars_gpsdata_errors(platform_metadata("ELECTRIC_GLIDER"), gps)

  expect_equal(nrow(errors), 0)
})

test_that("a stationary deployment without gpsdata is fine", {
  errors <- pars_gpsdata_errors(platform_metadata("BOTTOM_MOUNTED_MOORING"), NULL)

  expect_equal(nrow(errors), 0)
})

test_that("a stationary deployment with gps positions is reported", {
  gps <- tibble(row = 1L, deployment_code = "D1")

  errors <- pars_gpsdata_errors(platform_metadata("BOTTOM_MOUNTED_MOORING"), gps)

  expect_equal(nrow(errors), 1)
})

test_that("every mobile platform type is treated as mobile", {
  for (platform in PARS_MOBILE_PLATFORM_TYPES) {
    errors <- pars_gpsdata_errors(platform_metadata(platform), NULL)
    expect_equal(nrow(errors), 1, info = platform)
  }
})

test_that("the mobile platform list matches the six known platform types", {
  expect_setequal(
    PARS_MOBILE_PLATFORM_TYPES,
    c("DRIFTING_BUOY", "ELECTRIC_GLIDER", "TOWED_ARRAY", "WAVE_GLIDER")
  )
})

# loading --------------------------------------------------------------------

write_submission <- function(dir, metadata, detectiondata, gpsdata = NULL) {
  clean <- file.path(dir, "clean")
  dir.create(clean, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(metadata, file.path(clean, "metadata.csv"), na = "")
  readr::write_csv(detectiondata, file.path(clean, "detectiondata.csv"), na = "")
  if (!is.null(gpsdata)) {
    readr::write_csv(gpsdata, file.path(clean, "gpsdata.csv"), na = "")
  }
  invisible(dir)
}

test_that("a submission with no clean directory fails naming the submission", {
  root <- withr::local_tempdir()

  expect_error(
    load_pars("MISSING_SUB", "PARS_1.0", NA, root, test_codes()),
    "MISSING_SUB"
  )
})

test_that("a skipped submission returns NULL without reading files", {
  root <- withr::local_tempdir()

  expect_warning(
    result <- load_pars("SKIPPED", "PARS_1.0", "yes", root, test_codes()),
    "SKIPPED"
  )
  expect_null(result)
})

test_that("a valid submission loads with no errors and keeps its row counts", {
  root <- withr::local_tempdir()
  write_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(), -row),
    detectiondata = select(valid_detectiondata(), -row)
  )

  loaded <- load_pars("SUB1", "PARS_1.0", NA, root, test_codes())

  expect_equal(loaded$id, "SUB1")
  expect_equal(loaded$metadata[[1]]$n_rows, 1)
  expect_equal(loaded$detectiondata[[1]]$n_rows, 1)
  expect_true(loaded$metadata[[1]]$valid)
  expect_true(loaded$detectiondata[[1]]$valid)
})

test_that("gpsdata is optional and reported as absent", {
  root <- withr::local_tempdir()
  write_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(), -row),
    detectiondata = select(valid_detectiondata(), -row)
  )

  loaded <- load_pars("SUB1", "PARS_1.0", NA, root, test_codes())

  expect_null(loaded$gpsdata[[1]])
})

test_that("an invalid value in a loaded submission is surfaced as an error", {
  root <- withr::local_tempdir()
  write_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(recording_sample_rate_khz = 48000), -row),
    detectiondata = select(valid_detectiondata(), -row)
  )

  loaded <- load_pars("SUB1", "PARS_1.0", NA, root, test_codes())

  expect_false(loaded$metadata[[1]]$valid)
  expect_true(any(grepl(
    "recording_sample_rate_khz", loaded$metadata[[1]]$errors[[1]]$name
  )))
})

test_that("a broken cross-file reference is surfaced by the loader", {
  root <- withr::local_tempdir()
  write_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(), -row),
    detectiondata = select(
      valid_detectiondata(deployment_code = "NOT_IN_METADATA"), -row
    )
  )

  loaded <- load_pars("SUB1", "PARS_1.0", NA, root, test_codes())

  expect_true(nrow(loaded$errors[[1]]) > 0)
  expect_true(any(grepl("NOT_IN_METADATA", loaded$errors[[1]]$actual)))
})

test_that("the legacy profile is applied when the manifest says so", {
  root <- withr::local_tempdir()
  write_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(project_funding = NA_character_), -row),
    detectiondata = select(valid_detectiondata(), -row)
  )

  strict <- load_pars("SUB1", "PARS_1.0", NA, root, test_codes())
  relaxed <- load_pars("SUB1", "PARS_LEGACY", NA, root, test_codes())

  expect_false(strict$metadata[[1]]$valid)
  expect_true(relaxed$metadata[[1]]$valid)
})
