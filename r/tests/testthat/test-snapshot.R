test_that("a saved snapshot reads back identical to the original", {
  path <- withr::local_tempfile(fileext = ".rds")
  original <- fixture_snapshot()

  save_pacm_snapshot(original, path)
  restored <- read_pacm_snapshot(path)

  expect_equal(nrow(compare_pacm_snapshot(restored, original)), 0)
})

test_that("saving creates the parent directory if it does not exist", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "nested", "baseline.rds")

  save_pacm_snapshot(fixture_snapshot(), path)

  expect_true(file.exists(path))
})

test_that("reading a missing snapshot fails with an actionable message", {
  expect_error(
    read_pacm_snapshot("does/not/exist.rds"),
    "no baseline snapshot at"
  )
})

test_that("a changed track geometry is detected", {
  skip_if_not_installed("sf")

  baseline <- list(tracks = fixture_tracks())
  new <- list(tracks = fixture_tracks(shift = 0.5))

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 1)
  expect_equal(diffs$table, "tracks")
  expect_equal(diffs$column, "geometry")
})

test_that("identical track geometry reports no difference", {
  skip_if_not_installed("sf")

  baseline <- list(tracks = fixture_tracks())

  expect_equal(nrow(compare_pacm_snapshot(baseline, baseline)), 0)
})

test_that("compare_to_baseline reports no differences against its own capture", {
  path <- withr::local_tempfile(fileext = ".rds")
  x <- fixture_snapshot()
  capture_pacm_baseline(x, path)

  expect_equal(nrow(compare_to_baseline(x, path)), 0)
})

test_that("compare_to_baseline detects a change made after capture", {
  path <- withr::local_tempfile(fileext = ".rds")
  x <- fixture_snapshot()
  capture_pacm_baseline(x, path)

  changed <- x
  changed$deployments$platform_type[[1]] <- "DRIFTING_BUOY"

  diffs <- compare_to_baseline(changed, path)

  expect_equal(nrow(diffs), 1)
  expect_equal(diffs$column, "platform_type")
})

test_that("the default baseline path is under data-raw", {
  expect_match(PACM_BASELINE_PATH, "^data-raw/baseline/")
})
