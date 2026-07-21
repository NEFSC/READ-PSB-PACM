test_that("an empty supplement leaves the snapshot codes unchanged", {
  snapshot <- fixture_code_snapshot()

  codes <- union_reference_codes(snapshot, fixture_supplement())

  expect_equal(codes, snapshot$tables)
})

test_that("a supplement code is added to its existing table", {
  snapshot <- fixture_code_snapshot()
  supplement <- fixture_supplement(supplement_row("detectors", "ANALYST"))

  codes <- union_reference_codes(snapshot, supplement)

  expect_true("ANALYST" %in% codes$detectors)
  expect_equal(length(codes$detectors), 3)
})

test_that("a supplement code for a new table creates that table", {
  snapshot <- fixture_code_snapshot()
  supplement <- fixture_supplement(supplement_row("new_types", "SOMETHING"))

  codes <- union_reference_codes(snapshot, supplement)

  expect_equal(codes$new_types, "SOMETHING")
})

test_that("a supplement code already upstream does not duplicate", {
  snapshot <- fixture_code_snapshot()
  supplement <- fixture_supplement(supplement_row("detectors", "LFDCS"))

  codes <- union_reference_codes(snapshot, supplement)

  expect_equal(sum(codes$detectors == "LFDCS"), 1)
})

test_that("codes within a table stay sorted so the union is deterministic", {
  snapshot <- fixture_code_snapshot()
  supplement <- fixture_supplement(supplement_row("detectors", "AAA_FIRST"))

  codes <- union_reference_codes(snapshot, supplement)

  expect_equal(codes$detectors, sort(codes$detectors))
})

test_that("a supplement missing a required column is rejected", {
  snapshot <- fixture_code_snapshot()
  bad <- fixture_supplement(supplement_row("detectors", "ANALYST"))
  bad$rationale <- NULL

  expect_error(union_reference_codes(snapshot, bad), "rationale")
})

test_that("a supplement row without a rationale is rejected", {
  snapshot <- fixture_code_snapshot()
  bad <- fixture_supplement(
    supplement_row("detectors", "ANALYST", rationale = NA_character_)
  )

  expect_error(union_reference_codes(snapshot, bad), "rationale")
})

# reporting ------------------------------------------------------------------

test_that("the supplement report lists each supplement-sourced code", {
  supplement <- fixture_supplement(
    supplement_row("detectors", "ANALYST"),
    supplement_row("sound_sources", "UNKNOWN_SP")
  )

  report <- supplement_code_report(supplement, fixture_code_snapshot())

  expect_equal(nrow(report), 2)
  expect_setequal(report$code, c("ANALYST", "UNKNOWN_SP"))
})

test_that("a supplement code now present upstream is flagged retirable", {
  supplement <- fixture_supplement(
    supplement_row("detectors", "LFDCS"),
    supplement_row("detectors", "ANALYST")
  )

  report <- supplement_code_report(supplement, fixture_code_snapshot())

  expect_true(report$retirable[report$code == "LFDCS"])
  expect_false(report$retirable[report$code == "ANALYST"])
})

test_that("an empty supplement produces an empty report", {
  report <- supplement_code_report(fixture_supplement(), fixture_code_snapshot())

  expect_equal(nrow(report), 0)
})

# drift ----------------------------------------------------------------------

test_that("no drift is reported when upstream matches the snapshot", {
  snapshot <- fixture_code_snapshot()

  drift <- reference_code_drift(snapshot$tables, snapshot)

  expect_equal(nrow(drift), 0)
})

test_that("a code added upstream is reported as added", {
  snapshot <- fixture_code_snapshot()
  upstream <- snapshot$tables
  upstream$detectors <- c(upstream$detectors, "NEW_DETECTOR")

  drift <- reference_code_drift(upstream, snapshot)

  expect_equal(nrow(drift), 1)
  expect_equal(drift$change, "added_upstream")
  expect_equal(drift$code, "NEW_DETECTOR")
})

test_that("a code removed upstream is reported as removed", {
  snapshot <- fixture_code_snapshot()
  upstream <- snapshot$tables
  upstream$detectors <- "LFDCS"

  drift <- reference_code_drift(upstream, snapshot)

  expect_equal(nrow(drift), 1)
  expect_equal(drift$change, "removed_upstream")
  expect_equal(drift$code, "PAMGUARD_CLICK")
})

test_that("a table added upstream is reported", {
  snapshot <- fixture_code_snapshot()
  upstream <- snapshot$tables
  upstream$brand_new_table <- "CODE_A"

  drift <- reference_code_drift(upstream, snapshot)

  expect_equal(nrow(drift), 1)
  expect_equal(drift$table, "brand_new_table")
  expect_equal(drift$change, "added_upstream")
})

# snapshot io ----------------------------------------------------------------

test_that("a snapshot round-trips through disk with its version intact", {
  path <- withr::local_tempfile(fileext = ".json")
  write_reference_code_snapshot(fixture_code_snapshot()$tables, path, "1.0")

  restored <- read_reference_code_snapshot(path)

  expect_equal(restored$pars_template_version, "1.0")
  expect_equal(restored$tables, fixture_code_snapshot()$tables)
})

test_that("reading a missing snapshot fails with an actionable message", {
  expect_error(
    read_reference_code_snapshot("does/not/exist.json"),
    "no reference code snapshot at"
  )
})

test_that("a single-code table survives the json round-trip as a vector", {
  # jsonlite unboxes length-1 vectors unless told otherwise
  path <- withr::local_tempfile(fileext = ".json")
  write_reference_code_snapshot(list(only = "ONE_CODE"), path, "1.0")

  restored <- read_reference_code_snapshot(path)

  expect_equal(restored$tables$only, "ONE_CODE")
})
