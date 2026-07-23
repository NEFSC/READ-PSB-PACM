# export_deployments_table projects pacm_data$deployments to the CSV export.
# a fixture standing in for pacm_data$deployments: one Makara row, one PARS row.
export_deployments_fixture <- function () {
  tibble(
    deployment_organization_code = c("NEFSC", "SYRACUSE"),
    submission_id = c("MAKARA", "SYRACUSE_20260713"),
    deployment_id = c("NEFSC:D1", "SYRACUSE:D2"),
    source = c("MAKARA", "PARS"),
    latitude = c(41.5, 40.6),
    longitude = c(-70.1, -72.6)
  )
}

test_that("submission_id leads the exported table", {
  x <- export_deployments_table(export_deployments_fixture())

  expect_equal(names(x)[1], "submission_id")
})

test_that("every input deployment is preserved, one row each", {
  x <- export_deployments_table(export_deployments_fixture())

  expect_equal(nrow(x), 2)
  expect_equal(anyDuplicated(x$deployment_id), 0)
})

test_that("makara rows carry MAKARA and PARS rows carry the submission id", {
  x <- export_deployments_table(export_deployments_fixture())

  expect_equal(x$submission_id[x$source == "MAKARA"], "MAKARA")
  expect_equal(x$submission_id[x$source == "PARS"], "SYRACUSE_20260713")
})

test_that("the exported table is flat (no list-columns, CSV-writable)", {
  x <- export_deployments_table(export_deployments_fixture())

  expect_false(any(vapply(x, is.list, logical(1))))
})

test_that("all input columns survive the projection", {
  fixture <- export_deployments_fixture()
  x <- export_deployments_table(fixture)

  expect_setequal(names(x), names(fixture))
})
