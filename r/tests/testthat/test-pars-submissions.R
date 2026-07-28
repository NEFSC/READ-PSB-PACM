# the manifest is the pipeline definition, so a malformed one must fail loudly
# at read time rather than producing a pipeline that silently skips or misorders
# submissions. submission_date in particular orders supersession - a missing or
# unparseable date would make "the latest submission wins" arbitrary

PARS_TEST_MANIFEST_HEADER <- "submission_id,submission_date,format,skip,comment"

write_test_manifest <- function (rows, header = PARS_TEST_MANIFEST_HEADER) {
  path <- tempfile(fileext = ".csv")
  writeLines(c(header, rows), path)
  path
}

test_that("the real manifest reads with submission_date as a Date", {
  x <- read_pars_submissions(
    file.path("..", "..", "data-raw", "pars", "submissions.csv")
  )

  expect_s3_class(x$submission_date, "Date")
  expect_true(all(!is.na(x$submission_date)))
})

test_that("the real manifest keeps skip usable as a tar_map value", {
  x <- read_pars_submissions(
    file.path("..", "..", "data-raw", "pars", "submissions.csv")
  )

  # load_pars() tests `!is.na(skip)`, so an all-blank column must stay NA rather
  # than becoming an empty string
  expect_true(all(is.na(x$skip)))
})

test_that("a duplicate submission_id is rejected", {
  path <- write_test_manifest(c(
    "ORG_20250101,2025-01-01,PARS_1.0,,",
    "ORG_20250101,2025-02-01,PARS_1.0,,"
  ))

  expect_error(read_pars_submissions(path), "ORG_20250101")
})

test_that("a missing submission_date is rejected", {
  path <- write_test_manifest(c(
    "ORG_20250101,2025-01-01,PARS_1.0,,",
    "ORG_20250201,,PARS_1.0,,"
  ))

  expect_error(read_pars_submissions(path), "ORG_20250201")
})

test_that("an unparseable submission_date is rejected", {
  path <- write_test_manifest("ORG_20250101,not-a-date,PARS_1.0,,")

  expect_error(
    suppressWarnings(read_pars_submissions(path)), "ORG_20250101"
  )
})

test_that("a manifest with no submission_date column is rejected", {
  path <- write_test_manifest(
    "ORG_20250101,PARS_1.0,,",
    header = "submission_id,format,skip,comment"
  )

  # readr also warns that the named col_date parser matched no column; the error
  # is the contract, the warning is incidental
  expect_error(
    suppressWarnings(read_pars_submissions(path)), "submission_date"
  )
})

test_that("a well-formed manifest round-trips unchanged", {
  path <- write_test_manifest(c(
    "ORG_20250101,2025-01-01,PARS_1.0,,",
    "ORG_20250201,2025-02-01,PARS_LEGACY,,converted"
  ))

  x <- read_pars_submissions(path)

  expect_equal(nrow(x), 2)
  expect_equal(x$submission_id, c("ORG_20250101", "ORG_20250201"))
  expect_equal(x$submission_date, as.Date(c("2025-01-01", "2025-02-01")))
})
