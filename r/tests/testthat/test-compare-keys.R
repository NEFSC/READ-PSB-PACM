test_that("a composite key distinguishes rows sharing an id", {
  baseline <- list(analyses = fixture_multispecies_analyses())
  new <- baseline
  # change presence on the FIWH row, which shares analysis_id with the RIWH row
  new$analyses$call_type[[2]] <- "FW_20HZ"

  diffs <- compare_pacm_snapshot(
    new, baseline,
    keys = list(analyses = c("analysis_id", "species"))
  )

  expect_equal(nrow(diffs), 1)
  expect_equal(diffs$key, "ORG:DEP1:ANALYSIS | FIWH")
  expect_equal(diffs$column, "call_type")
})

test_that("a non-unique key is rejected rather than silently compared", {
  x <- list(analyses = fixture_multispecies_analyses())

  expect_error(
    compare_pacm_snapshot(x, x, keys = list(analyses = "analysis_id")),
    "not unique"
  )
})

test_that("the error names the table and the offending key", {
  x <- list(analyses = fixture_multispecies_analyses())

  expect_error(
    compare_pacm_snapshot(x, x, keys = list(analyses = "analysis_id")),
    "analyses"
  )
})

test_that("the default keys make every pacm_data table uniquely identified", {
  # analyses is keyed by analysis_id + species because one Makara analysis
  # covers multiple species under a single analysis_id
  expect_equal(PACM_SNAPSHOT_KEYS$analyses, c("analysis_id", "species"))
  expect_true("citations" %in% names(PACM_SNAPSHOT_KEYS))
})

test_that("a duplicate key introduced only in the new snapshot is caught", {
  baseline <- list(analyses = fixture_multispecies_analyses())
  new <- baseline
  new$analyses$species[[2]] <- "RIWH"

  expect_error(
    compare_pacm_snapshot(
      new, baseline,
      keys = list(analyses = c("analysis_id", "species"))
    ),
    "not unique"
  )
})

test_that("a table missing from the new snapshot reports all rows removed", {
  # towed_pacm carries sites = NULL, so a NULL table is a real shape
  baseline <- list(deployments = fixture_deployments())
  new <- list(deployments = NULL)

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 2)
  expect_true(all(diffs$change == "removed"))
})

test_that("a table missing from the baseline reports all rows added", {
  baseline <- list(deployments = NULL)
  new <- list(deployments = fixture_deployments())

  diffs <- compare_pacm_snapshot(new, baseline)

  expect_equal(nrow(diffs), 2)
  expect_true(all(diffs$change == "added"))
})

test_that("a table absent from both snapshots is skipped", {
  expect_equal(nrow(compare_pacm_snapshot(list(), list())), 0)
})
