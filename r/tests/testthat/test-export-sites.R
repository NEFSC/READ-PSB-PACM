# export_sites_table projects pacm_data$sites verbatim. Sites are 1:1 with
# deployments via site_id, so the export carries NO submission_id.
export_sites_fixture <- function () {
  tibble(
    deployment_organization_code = c("NEFSC", "SYRACUSE"),
    site_id = c("NEFSC:S1", "SYRACUSE:LI01"),
    site = c("S1", "LI01"),
    site_latitude = c(41.5, 40.6),
    site_longitude = c(-70.1, -72.6)
  )
}

test_that("sites export carries no submission_id", {
  x <- export_sites_table(export_sites_fixture())

  expect_false("submission_id" %in% names(x))
})

test_that("every site is preserved, one row each", {
  x <- export_sites_table(export_sites_fixture())

  expect_equal(nrow(x), 2)
  expect_equal(anyDuplicated(x$site_id), 0)
})

test_that("the exported table is flat (no list-columns)", {
  x <- export_sites_table(export_sites_fixture())

  expect_false(any(vapply(x, is.list, logical(1))))
})
