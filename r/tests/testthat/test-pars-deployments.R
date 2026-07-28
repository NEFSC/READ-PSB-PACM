pars_metadata_row <- function(...) {
  base <- tibble(
    submission_id = "SUB1",
    deployment_organization_code = "SYRACUSE",
    deployment_code = "SYRACUSE_LI01",
    project_name = "SYRACUSE_NYNJB_LI",
    site_code = "LI01",
    monitoring_start_datetime = parse_pars_datetime("2025-04-24T17:29:04Z"),
    monitoring_end_datetime = parse_pars_datetime("2025-08-13T15:02:53Z"),
    deployment_latitude = 40.584867,
    deployment_longitude = -72.585167,
    deployment_platform_type_code = "BOTTOM_MOUNTED_MOORING",
    deployment_platform_id = "SOUNDTRAP-LI01",
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
    dynamic_management_platform = FALSE,
    deployment_url = NA_character_,
    points_of_contact = "Susan Parks <sparks@syr.edu>",
    project_funding = "ASMFC 25-0108"
  )
  overrides <- list(...)
  for (n in names(overrides)) base[[n]] <- overrides[[n]]
  base
}

test_that("deployment_id is organization and deployment code", {
  x <- pars_deployments_table(pars_metadata_row())

  expect_equal(as.character(x$deployment_id), "SYRACUSE:SYRACUSE_LI01")
})

test_that("the sample rate converts kHz to Hz in the published format", {
  # published sampling_rate_hz is a formatted string, not a number
  x <- pars_deployments_table(pars_metadata_row(recording_sample_rate_khz = 48))

  expect_equal(x$sampling_rate_hz, "48,000")
  expect_type(x$sampling_rate_hz, "character")
})

test_that("a decimal kHz sample rate converts correctly", {
  x <- pars_deployments_table(pars_metadata_row(recording_sample_rate_khz = 0.5))

  expect_equal(x$sampling_rate_hz, "500")
})

test_that("a mooring is stationary", {
  x <- pars_deployments_table(
    pars_metadata_row(deployment_platform_type_code = "BOTTOM_MOUNTED_MOORING")
  )

  expect_equal(x$deployment_type, "STATIONARY")
})

test_that("a glider is mobile", {
  x <- pars_deployments_table(
    pars_metadata_row(deployment_platform_type_code = "ELECTRIC_GLIDER")
  )

  expect_equal(x$deployment_type, "MOBILE")
})

test_that("PARS field names map onto the published names", {
  x <- pars_deployments_table(pars_metadata_row())

  expect_equal(x$project, "SYRACUSE_NYNJB_LI")
  expect_equal(x$site, "LI01")
  expect_equal(x$latitude, 40.584867)
  expect_equal(x$longitude, -72.585167)
  expect_equal(x$water_depth_meters, 40)
  expect_equal(x$instrument_type, "SOUNDTRAP")
  expect_equal(as.character(x$data_poc), "Susan Parks <sparks@syr.edu>")
})

test_that("recorder depth is published as character, matching other sources", {
  x <- pars_deployments_table(pars_metadata_row())

  expect_type(x$recorder_depth_meters, "character")
  expect_equal(x$recorder_depth_meters, "37")
})

test_that("source is tagged PARS and the device is not marked lost", {
  x <- pars_deployments_table(pars_metadata_row())

  expect_equal(x$source, "PARS")
  expect_false(x$recording_device_lost)
})

test_that("dynamic_management_platform carries the submitted value", {
  x <- pars_deployments_table(pars_metadata_row(dynamic_management_platform = TRUE))

  expect_true(x$dynamic_management_platform)
  expect_type(x$dynamic_management_platform, "logical")
})

test_that("the new PARS fields are carried through", {
  x <- pars_deployments_table(
    pars_metadata_row(deployment_url = "https://example.org/d1")
  )

  expect_equal(x$project_funding, "ASMFC 25-0108")
  expect_equal(x$deployment_url, "https://example.org/d1")
  expect_equal(x$recording_duration_secs, 14400)
  expect_equal(x$recording_interval_secs, 14400)
})

test_that("the internal organization_code column is kept for site derivation", {
  # derive_sites() expects organization_code, matching the legacy path
  x <- pars_deployments_table(pars_metadata_row())

  expect_true("organization_code" %in% names(x))
  expect_equal(x$organization_code, "SYRACUSE")
})

test_that("multiple deployments each get their own id", {
  x <- pars_deployments_table(bind_rows(
    pars_metadata_row(deployment_code = "D1"),
    pars_metadata_row(deployment_code = "D2")
  ))

  expect_equal(nrow(x), 2)
  expect_equal(anyDuplicated(x$deployment_id), 0)
})

test_that("deployments feed derive_sites and produce site ids", {
  deployments <- pars_deployments_table(bind_rows(
    pars_metadata_row(deployment_code = "D1", site_code = "LI01"),
    pars_metadata_row(deployment_code = "D2", site_code = "LI02")
  ))

  sites <- derive_sites(deployments)

  expect_equal(nrow(sites), 2)
  expect_setequal(as.character(sites$site_id), c("SYRACUSE:LI01", "SYRACUSE:LI02"))
})

# supersession ---------------------------------------------------------------
#
# these exercise the composition the pars_deployments target performs:
# pars_deployments_table() then pars_supersede() on deployment_id

deployment_submissions <- function (...) {
  dots <- c(...)
  tibble(
    submission_id = names(dots),
    submission_date = as.Date(unname(dots))
  )
}

test_that("a deployment redefined by a later submission keeps the later values", {
  metadata <- bind_rows(
    pars_metadata_row(submission_id = "SUB1", deployment_water_depth_m = 40),
    pars_metadata_row(submission_id = "SUB2", deployment_water_depth_m = 55)
  )

  out <- pars_supersede(
    pars_deployments_table(metadata), "deployment_id", "deployment",
    deployment_submissions(SUB1 = "2025-01-01", SUB2 = "2025-06-01")
  )

  expect_equal(nrow(out$current), 1)
  expect_equal(out$current$water_depth_meters, 55)
  expect_equal(out$current$submission_id, "SUB2")
})

test_that("the superseded deployment is reported with both submissions", {
  metadata <- bind_rows(
    pars_metadata_row(submission_id = "SUB1"),
    pars_metadata_row(submission_id = "SUB2")
  )

  out <- pars_supersede(
    pars_deployments_table(metadata), "deployment_id", "deployment",
    deployment_submissions(SUB1 = "2025-01-01", SUB2 = "2025-06-01")
  )

  expect_equal(nrow(out$superseded), 1)
  expect_equal(out$superseded$entity, "deployment")
  expect_equal(out$superseded$entity_id, "SYRACUSE:SYRACUSE_LI01")
  expect_equal(out$superseded$superseded_submission_id, "SUB1")
  expect_equal(out$superseded$superseding_submission_id, "SUB2")
})

test_that("the surviving deployments satisfy the uniqueness assertion", {
  metadata <- bind_rows(
    pars_metadata_row(submission_id = "SUB1", deployment_code = "D1"),
    pars_metadata_row(submission_id = "SUB2", deployment_code = "D1"),
    pars_metadata_row(submission_id = "SUB2", deployment_code = "D2")
  )

  out <- pars_supersede(
    pars_deployments_table(metadata), "deployment_id", "deployment",
    deployment_submissions(SUB1 = "2025-01-01", SUB2 = "2025-06-01")
  )

  expect_equal(nrow(out$current), 2)
  expect_equal(anyDuplicated(out$current$deployment_id), 0)
})

test_that("deployments only in the earlier submission still survive", {
  metadata <- bind_rows(
    pars_metadata_row(submission_id = "SUB1", deployment_code = "D1"),
    pars_metadata_row(submission_id = "SUB1", deployment_code = "D2"),
    pars_metadata_row(submission_id = "SUB2", deployment_code = "D1")
  )

  out <- pars_supersede(
    pars_deployments_table(metadata), "deployment_id", "deployment",
    deployment_submissions(SUB1 = "2025-01-01", SUB2 = "2025-06-01")
  )

  d2 <- out$current[out$current$deployment_code == "D2", ]
  expect_equal(nrow(d2), 1)
  expect_equal(d2$submission_id, "SUB1")
})

test_that("two submissions claiming one deployment on the same date is an error", {
  metadata <- bind_rows(
    pars_metadata_row(submission_id = "SUB1"),
    pars_metadata_row(submission_id = "SUB2")
  )

  expect_error(
    pars_supersede(
      pars_deployments_table(metadata), "deployment_id", "deployment",
      deployment_submissions(SUB1 = "2025-01-01", SUB2 = "2025-01-01")
    ),
    "SYRACUSE:SYRACUSE_LI01"
  )
})

test_that("a superseded deployment cannot influence site derivation", {
  # the earlier submission put the deployment >10km away; if it survived,
  # derive_sites would split the site into two versions
  metadata <- bind_rows(
    pars_metadata_row(
      submission_id = "SUB1", deployment_latitude = 41.6,
      deployment_longitude = -72.585167
    ),
    pars_metadata_row(submission_id = "SUB2")
  )

  out <- pars_supersede(
    pars_deployments_table(metadata), "deployment_id", "deployment",
    deployment_submissions(SUB1 = "2025-01-01", SUB2 = "2025-06-01")
  )
  sites <- derive_sites(out$current)

  expect_equal(nrow(sites), 1)
  expect_equal(as.character(sites$site_id), "SYRACUSE:LI01")
})

test_that("every published deployment column is present", {
  x <- pars_deployments_table(pars_metadata_row())
  published <- c(
    "deployment_id", "deployment_code", "project", "site", "latitude",
    "longitude", "monitoring_start_datetime", "monitoring_end_datetime",
    "platform_type", "deployment_type", "water_depth_meters",
    "recorder_depth_meters", "instrument_type", "sampling_rate_hz", "data_poc",
    "recording_device_lost", "dynamic_management_platform", "source"
  )

  expect_true(all(published %in% names(x)))
})

# deployment_code ambiguity ---------------------------------------------------
#
# detectiondata carries no deployment-organization column (PARS_REQUIRED in
# pars-validate.R), so pars_analyses_table can only join a detection row to its
# deployment by bare deployment_code. two organizations using the same code make
# that join ambiguous, and nothing downstream notices - hence the guard.

test_that("a deployment_code shared by two organizations is rejected", {
  deployments <- pars_deployments_table(bind_rows(
    pars_metadata_row(
      deployment_organization_code = "SYRACUSE", deployment_code = "D1"
    ),
    pars_metadata_row(
      deployment_organization_code = "NEFSC", deployment_code = "D1"
    )
  ))

  expect_error(pars_check_deployment_codes(deployments), "D1")
})

test_that("the shared-code error names both organizations", {
  deployments <- pars_deployments_table(bind_rows(
    pars_metadata_row(
      deployment_organization_code = "SYRACUSE", deployment_code = "D1"
    ),
    pars_metadata_row(
      deployment_organization_code = "NEFSC", deployment_code = "D1"
    )
  ))

  err <- expect_error(pars_check_deployment_codes(deployments))

  expect_match(conditionMessage(err), "SYRACUSE")
  expect_match(conditionMessage(err), "NEFSC")
})

test_that("the same code in one organization is not a cross-org conflict", {
  # that is a duplicate deployment_id, which anyDuplicated already rejects; this
  # guard is only about the code being ambiguous ACROSS organizations
  deployments <- pars_deployments_table(bind_rows(
    pars_metadata_row(deployment_code = "D1"),
    pars_metadata_row(deployment_code = "D1")
  ))

  expect_no_error(pars_check_deployment_codes(deployments))
})

test_that("distinct codes across organizations are fine", {
  deployments <- pars_deployments_table(bind_rows(
    pars_metadata_row(
      deployment_organization_code = "SYRACUSE", deployment_code = "D1"
    ),
    pars_metadata_row(
      deployment_organization_code = "NEFSC", deployment_code = "D2"
    )
  ))

  expect_no_error(pars_check_deployment_codes(deployments))
})

test_that("the real PARS deployments have no ambiguous codes", {
  skip_if_not(file.exists(file.path("..", "..", "_targets", "objects", "pars_deployments")))

  expect_no_error(
    pars_check_deployment_codes(targets::tar_read(
      pars_deployments, store = file.path("..", "..", "_targets")
    ))
  )
})
