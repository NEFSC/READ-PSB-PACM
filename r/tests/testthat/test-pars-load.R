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
#
# Referential integrity is GLOBAL, not per-submission: a detection may analyse
# a deployment whose metadata another submission provided - the DFO recorders
# JASCO analysed. `pars_referential_errors` therefore runs on the combined
# pool. Only within-submission deployment_code uniqueness stays local.

ref_metadata <- function(codes = c("D1", "D2")) {
  tibble(row = seq_along(codes), deployment_code = codes)
}

ref_detectiondata <- function(codes = c("D1", "D2")) {
  tibble(row = seq_along(codes), deployment_code = codes)
}

test_that("a duplicated deployment_code within a submission is reported", {
  errors <- pars_metadata_errors(ref_metadata(c("D1", "D1")))

  expect_true(any(grepl("unique", errors$name)))
})

test_that("a unique deployment_code set produces no metadata errors", {
  expect_equal(nrow(pars_metadata_errors(ref_metadata())), 0)
})

test_that("matching deployment codes produce no referential errors", {
  errors <- pars_referential_errors(ref_metadata(), ref_detectiondata(), NULL)

  expect_equal(nrow(errors), 0)
})

test_that("a detection referencing a deployment in the pool is not an orphan", {
  # the cross-submission case: metadata lists D1+D2, a detection analyses D2
  # (which another submission might have deployed) - fine against the pool
  errors <- pars_referential_errors(
    ref_metadata(c("D1", "D2")),
    ref_detectiondata(c("D2")),
    NULL
  )

  expect_equal(nrow(errors), 0)
})

test_that("a detectiondata code absent from the whole pool is reported", {
  errors <- pars_referential_errors(
    ref_metadata(c("D1")),
    ref_detectiondata(c("D1", "GHOST")),
    NULL
  )

  expect_equal(nrow(errors), 1)
  expect_true(grepl("GHOST", errors$actual))
  expect_equal(errors$row, 2)
})

test_that("a gpsdata code absent from the pool is reported", {
  gps <- tibble(row = 1L, deployment_code = "GHOST")

  errors <- pars_referential_errors(ref_metadata(), ref_detectiondata(), gps)

  expect_equal(nrow(errors), 1)
  expect_true(grepl("gpsdata", errors$name))
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

write_raw_submission <- function(dir, metadata, detectiondata, gpsdata = NULL) {
  raw <- file.path(dir, "raw")
  dir.create(raw, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(metadata, file.path(raw, "metadata.csv"), na = "")
  readr::write_csv(detectiondata, file.path(raw, "detectiondata.csv"), na = "")
  if (!is.null(gpsdata)) {
    readr::write_csv(gpsdata, file.path(raw, "gpsdata.csv"), na = "")
  }
  invisible(dir)
}

test_that("a submission with neither clean/ nor raw/ fails naming the submission", {
  root <- withr::local_tempdir()

  expect_error(
    load_pars("MISSING_SUB", "PARS_1.0", NA, root, test_codes()),
    "MISSING_SUB"
  )
})

test_that("a conforming submission (raw/ only, no clean.R) loads directly from raw/", {
  # a submission needing no corrections has no clean.R and no clean/;
  # the loader reads raw/ directly rather than demanding a clean/ that a
  # conforming submission would never produce
  root <- withr::local_tempdir()
  write_raw_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(), -row),
    detectiondata = select(valid_detectiondata(), -row)
  )

  loaded <- load_pars("SUB1", "PARS_1.0", NA, root, test_codes())

  expect_equal(loaded$id, "SUB1")
  expect_equal(loaded$metadata[[1]]$n_rows, 1)
  expect_true(loaded$metadata[[1]]$valid)
  expect_true(loaded$detectiondata[[1]]$valid)
})

test_that("clean/ takes precedence over raw/ when both exist", {
  # a submission with corrections must read the corrected clean/, never raw/
  root <- withr::local_tempdir()
  write_raw_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(recording_sample_rate_khz = 48000), -row),
    detectiondata = select(valid_detectiondata(), -row)
  )
  write_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(recording_sample_rate_khz = 48), -row),
    detectiondata = select(valid_detectiondata(), -row)
  )

  loaded <- load_pars("SUB1", "PARS_1.0", NA, root, test_codes())

  # clean/ has the corrected 48 kHz; raw/ still has the bad 48000
  expect_true(loaded$metadata[[1]]$valid)
})

test_that("a clean.R with no generated clean/ fails rather than silently reading raw/", {
  # a submission that HAS corrections to apply but whose clean/ was never
  # generated is a mistake, not a conforming submission: reading raw/ would
  # ingest the very values clean.R exists to fix. it must stop and say so.
  root <- withr::local_tempdir()
  sub <- file.path(root, "SUB1")
  write_raw_submission(
    sub,
    metadata = select(valid_metadata(recording_sample_rate_khz = 48000), -row),
    detectiondata = select(valid_detectiondata(), -row)
  )
  writeLines("# corrections not yet run", file.path(sub, "clean.R"))

  expect_error(
    load_pars("SUB1", "PARS_1.0", NA, root, test_codes()),
    "clean"
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

test_that("a loaded file reports its error count alongside the errors", {
  root <- withr::local_tempdir()
  write_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(deployment_platform_type_code = "SPACE_STATION"), -row),
    detectiondata = select(valid_detectiondata(), -row)
  )

  loaded <- load_pars("SUB1", "PARS_1.0", NA, root, test_codes())
  metadata <- loaded$metadata[[1]]

  # n_errors was silently absent: `nrow(errors)` inside tibble() resolved to the
  # list-column being created, and a NULL column is dropped without complaint
  expect_true("n_errors" %in% names(metadata))
  expect_equal(metadata$n_errors, nrow(metadata$errors[[1]]))
  expect_gt(metadata$n_errors, 0)
})

test_that("a valid file reports zero errors rather than a missing count", {
  root <- withr::local_tempdir()
  write_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(), -row),
    detectiondata = select(valid_detectiondata(), -row)
  )

  loaded <- load_pars("SUB1", "PARS_1.0", NA, root, test_codes())

  expect_equal(loaded$metadata[[1]]$n_errors, 0)
  expect_equal(loaded$detectiondata[[1]]$n_errors, 0)
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

test_that("a cross-submission reference is NOT a per-submission error", {
  # referential integrity is global: a detection may analyse a deployment
  # another submission provided, so load_pars must not flag a deployment_code
  # absent from THIS submission's own metadata. the orphan check runs on the
  # combined pool (pars_referential_errors, tested above)
  root <- withr::local_tempdir()
  write_submission(
    file.path(root, "SUB1"),
    metadata = select(valid_metadata(), -row),
    detectiondata = select(
      valid_detectiondata(deployment_code = "IN_ANOTHER_SUBMISSION"), -row
    )
  )

  loaded <- load_pars("SUB1", "PARS_1.0", NA, root, test_codes())

  expect_equal(nrow(loaded$errors[[1]]), 0)
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
