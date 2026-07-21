test_that("identical snapshots report no differences", {
  x <- fixture_snapshot()

  diffs <- compare_pacm_snapshot(x, x)

  expect_equal(nrow(diffs), 0)
})

test_that("a changed scalar field is reported with both values", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$deployments$platform_type[[2]] <- "WAVE_GLIDER"

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 1)
  expect_equal(diffs$table, "deployments")
  expect_equal(diffs$key, "ORG:DEP2")
  expect_equal(diffs$change, "changed")
  expect_equal(diffs$column, "platform_type")
  expect_equal(diffs$baseline_value, "ELECTRIC_GLIDER")
  expect_equal(diffs$new_value, "WAVE_GLIDER")
})

test_that("an added row is reported as added, not changed", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$deployments <- bind_rows(
    new$deployments,
    tibble(
      deployment_id = "ORG:DEP3", site_id = "ORG:SITE3", latitude = 43.0,
      sampling_rate_hz = 48000, platform_type = "DRIFTING_BUOY"
    )
  )

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 1)
  expect_equal(diffs$change, "added")
  expect_equal(diffs$key, "ORG:DEP3")
})

test_that("a removed row is reported as removed", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$deployments <- filter(new$deployments, deployment_id != "ORG:DEP1")

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 1)
  expect_equal(diffs$change, "removed")
  expect_equal(diffs$key, "ORG:DEP1")
})

test_that("row order does not affect the comparison", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$deployments <- arrange(new$deployments, desc(deployment_id))

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 0)
})

test_that("float drift within tolerance is ignored", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$deployments$latitude[[1]] <- 41.5 + 1e-12

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 0)
})

test_that("float change beyond tolerance is reported", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$deployments$latitude[[1]] <- 41.6

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 1)
  expect_equal(diffs$column, "latitude")
})

test_that("a change inside a nested detections table is detected", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$analyses$detections[[1]]$presence[[2]] <- "y"

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 1)
  expect_equal(diffs$table, "analyses")
  expect_equal(diffs$key, "ORG:DEP1:RIWH | RIWH")
  expect_equal(diffs$column, "detections")
})

test_that("added and removed rows in a nested table are detected", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$analyses$detections[[2]] <- tibble(
    date = as.Date(c("2025-02-01", "2025-02-02")),
    presence = c("m", "n")
  )

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 1)
  expect_equal(diffs$column, "detections")
})

test_that("a column present in one snapshot but not the other is reported", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$deployments$new_field <- c("a", "b")

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_true(any(diffs$change == "column_added"))
  expect_true("new_field" %in% diffs$column)
})

test_that("differences across multiple tables are all reported", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$deployments$platform_type[[1]] <- "MOORED_SURFACE_BUOY"
  new$analyses$deployment_id[[1]] <- "ORG:DEP9"

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 2)
  expect_setequal(diffs$table, c("deployments", "analyses"))
})

test_that("changing a key column reads as a removed row plus an added row", {
  baseline <- fixture_snapshot()
  new <- baseline
  new$analyses$species[[1]] <- "HUWH"

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_setequal(diffs$change, c("removed", "added"))
  expect_setequal(
    diffs$key,
    c("ORG:DEP1:RIWH | RIWH", "ORG:DEP1:RIWH | HUWH")
  )
})

test_that("NA values compare equal to NA and unequal to a value", {
  baseline <- fixture_snapshot()
  baseline$deployments$platform_type[[1]] <- NA_character_
  new <- baseline

  expect_equal(nrow(compare_pacm_snapshot(new, baseline)), 0)

  new$deployments$platform_type[[1]] <- "BOTTOM_MOUNTED_MOORING"
  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 1)
  expect_true(is.na(diffs$baseline_value))
})

test_that("datetime columns are compared without error", {
  # POSIXct is stored as a double, so naive rounding dispatches to round.POSIXt
  # and fails; pacm_data carries monitoring_start_datetime on every deployment
  baseline <- fixture_snapshot()
  baseline$deployments$monitoring_start_datetime <- as.POSIXct(
    c("2025-01-01 00:00:00", "2025-02-01 00:00:00"), tz = "UTC"
  )
  new <- baseline

  expect_equal(nrow(compare_pacm_snapshot(new, baseline)), 0)
})

test_that("a changed datetime is detected", {
  baseline <- fixture_snapshot()
  baseline$deployments$monitoring_start_datetime <- as.POSIXct(
    c("2025-01-01 00:00:00", "2025-02-01 00:00:00"), tz = "UTC"
  )
  new <- baseline
  new$deployments$monitoring_start_datetime[[1]] <- as.POSIXct(
    "2025-01-05 00:00:00", tz = "UTC"
  )

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 1)
  expect_equal(diffs$column, "monitoring_start_datetime")
})

test_that("datetimes nested inside a list-column are compared without error", {
  baseline <- fixture_snapshot()
  baseline$analyses$detections[[1]]$datetime <- as.POSIXct(
    c("2025-01-01 00:00:00", "2025-01-02 00:00:00"), tz = "UTC"
  )
  new <- baseline

  expect_equal(nrow(compare_pacm_snapshot(new, baseline)), 0)
})
