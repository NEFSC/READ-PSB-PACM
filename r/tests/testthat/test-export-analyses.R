# export_analyses_table projects pacm_data$analyses to the flat analyses CSV,
# dropping the nested detections list-column (exported separately).
export_analyses_fixture <- function () {
  tibble(
    deployment_id = c("NEFSC:D1", "SYRACUSE:D2"),
    submission_id = c("MAKARA", "USYRA_20260713"),
    analysis_id = c("NEFSC:D1:RIWH", "SYRACUSE:D2:RIWH"),
    species = c("RIWH", "RIWH"),
    citations = c("NEFSC:PARS_1", NA_character_),
    detections = list(
      tibble(date = as.Date("2025-01-01"), presence = "y"),
      tibble(date = as.Date("2025-02-01"), presence = "n")
    )
  )
}

test_that("submission_id leads the exported table", {
  x <- export_analyses_table(export_analyses_fixture())

  expect_equal(names(x)[1], "submission_id")
})

test_that("the nested detections list-column is dropped", {
  x <- export_analyses_table(export_analyses_fixture())

  expect_false("detections" %in% names(x))
})

test_that("the exported table is flat (no list-columns, CSV-writable)", {
  x <- export_analyses_table(export_analyses_fixture())

  expect_false(any(vapply(x, is.list, logical(1))))
})

test_that("one row per analysis is preserved with its submission_id", {
  x <- export_analyses_table(export_analyses_fixture())

  expect_equal(nrow(x), 2)
  expect_equal(anyDuplicated(x$analysis_id), 0)
  expect_equal(x$submission_id[x$analysis_id == "NEFSC:D1:RIWH"], "MAKARA")
  expect_equal(x$submission_id[x$analysis_id == "SYRACUSE:D2:RIWH"], "USYRA_20260713")
})
