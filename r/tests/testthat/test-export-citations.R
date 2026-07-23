# export_citations_table projects pacm_data$citations verbatim. Citations are a
# reference table resolvable to submissions via analyses.csv on `code`, so the
# export carries NO submission_id.
export_citations_fixture <- function () {
  tibble(
    code = c("NEFSC:PARS_1", "SYRACUSE:PARS_1"),
    reference = c("Davis et al. 2020", "Parks et al. 2022")
  )
}

test_that("citations export carries no submission_id", {
  x <- export_citations_table(export_citations_fixture())

  expect_false("submission_id" %in% names(x))
})

test_that("every citation code is preserved, one row each", {
  x <- export_citations_table(export_citations_fixture())

  expect_equal(nrow(x), 2)
  expect_equal(anyDuplicated(x$code), 0)
})

test_that("the exported table is flat (no list-columns)", {
  x <- export_citations_table(export_citations_fixture())

  expect_false(any(vapply(x, is.list, logical(1))))
})
