# datetimes ------------------------------------------------------------------

test_that("a colon-separated offset parses to the correct instant", {
  x <- parse_pars_datetime("2025-04-25T00:00:00-04:00")

  expect_equal(format(x, tz = "UTC"), "2025-04-25 04:00:00")
})

test_that("a compact offset parses to the same instant as the colon form", {
  colon <- parse_pars_datetime("2025-04-25T00:00:00-04:00")
  compact <- parse_pars_datetime("2025-04-25T00:00:00-0400")

  expect_equal(colon, compact)
})

test_that("a Zulu suffix parses as UTC", {
  x <- parse_pars_datetime("2025-04-25T12:00:00Z")

  expect_equal(format(x, tz = "UTC"), "2025-04-25 12:00:00")
})

test_that("a zero offset written -00:00 parses", {
  # USYRA metadata uses this form
  x <- parse_pars_datetime("2025-04-24T17:29:04-00:00")

  expect_equal(format(x, tz = "UTC"), "2025-04-24 17:29:04")
})

test_that("a naive timestamp is rejected rather than assumed UTC", {
  expect_true(is.na(parse_pars_datetime("2025-04-25T00:00:00")))
})

test_that("a blank datetime is NA, not an error", {
  expect_true(is.na(parse_pars_datetime("")))
  expect_true(is.na(parse_pars_datetime(NA_character_)))
})

test_that("a space separator is accepted when the offset is present", {
  x <- parse_pars_datetime("2025-04-25 00:00:00-04:00")

  expect_equal(format(x, tz = "UTC"), "2025-04-25 04:00:00")
})

test_that("a malformed datetime is NA rather than a silent coercion", {
  expect_true(is.na(parse_pars_datetime("not a date")))
  expect_true(is.na(parse_pars_datetime("2025-13-45T99:99:99-04:00")))
})

test_that("datetimes parse as a vector, preserving position", {
  x <- parse_pars_datetime(c(
    "2025-04-25T00:00:00Z", "", "2025-04-26T00:00:00Z", "2025-04-27T00:00:00"
  ))

  expect_equal(length(x), 4)
  expect_false(is.na(x[[1]]))
  expect_true(is.na(x[[2]]))
  expect_false(is.na(x[[3]]))
  expect_true(is.na(x[[4]]))
})

# numbers --------------------------------------------------------------------

test_that("numbers parse and blanks become NA", {
  x <- parse_pars_number(c("48", "0.5", "", NA))

  expect_equal(x, c(48, 0.5, NA, NA))
})

test_that("a non-numeric value becomes NA rather than erroring", {
  expect_true(is.na(parse_pars_number("abc")))
})

test_that("integers parse to integer type", {
  x <- parse_pars_integer(c("16", "1", ""))

  expect_equal(x, c(16L, 1L, NA_integer_))
})

test_that("booleans parse case-insensitively", {
  expect_equal(parse_pars_boolean(c("TRUE", "false", "")), c(TRUE, FALSE, NA))
})

test_that("a non-boolean string becomes NA", {
  expect_true(is.na(parse_pars_boolean("YES")))
})

# placeholders ---------------------------------------------------------------

test_that("literal NA and NULL placeholders are reported, not silently blanked", {
  raw <- tibble(
    row = 1:3,
    deployment_code = c("D1", "NA", "D3"),
    project_funding = c("NULL", "OK", "-")
  )

  errors <- pars_placeholder_errors(raw)

  expect_equal(nrow(errors), 3)
  expect_setequal(errors$column, c("deployment_code", "project_funding"))
})

test_that("placeholder detection is case-insensitive and ignores whitespace", {
  raw <- tibble(row = 1L, site_code = " null ")

  expect_equal(nrow(pars_placeholder_errors(raw)), 1)
})

test_that("genuinely blank cells are not placeholder errors", {
  raw <- tibble(row = 1:2, site_code = c("", NA_character_))

  expect_equal(nrow(pars_placeholder_errors(raw)), 0)
})

test_that("a value merely containing NA is not flagged", {
  # NARW must not trip the NA placeholder check
  raw <- tibble(row = 1L, species = "NARW")

  expect_equal(nrow(pars_placeholder_errors(raw)), 0)
})

test_that("the row column itself is never reported", {
  raw <- tibble(row = 1L, value = "OK")

  expect_equal(nrow(pars_placeholder_errors(raw)), 0)
})

# table parsers --------------------------------------------------------------

test_that("metadata parses its numeric and datetime columns", {
  raw <- tibble(
    row = 1L,
    deployment_code = "D1",
    monitoring_start_datetime = "2025-04-25T00:00:00Z",
    deployment_latitude = "41.5",
    recording_sample_rate_khz = "48",
    recording_bit_depth = "16",
    dynamic_management_platform = "FALSE"
  )

  parsed <- parse_pars_metadata(raw)

  expect_s3_class(parsed$monitoring_start_datetime, "POSIXct")
  expect_type(parsed$deployment_latitude, "double")
  expect_equal(parsed$recording_sample_rate_khz, 48)
  expect_type(parsed$recording_bit_depth, "integer")
  expect_type(parsed$dynamic_management_platform, "logical")
})

test_that("metadata parsing leaves absent optional columns alone", {
  raw <- tibble(row = 1L, deployment_code = "D1")

  parsed <- parse_pars_metadata(raw)

  expect_equal(parsed$deployment_code, "D1")
})

test_that("detectiondata parses its numeric and datetime columns", {
  raw <- tibble(
    row = 1L,
    deployment_code = "D1",
    analysis_start_datetime = "2025-04-25T00:00:00Z",
    detection_start_datetime = "2025-04-25T00:00:00Z",
    analysis_sample_rate_khz = "2",
    detection_n_validated = "5",
    localization_latitude = "41.5"
  )

  parsed <- parse_pars_detectiondata(raw)

  expect_s3_class(parsed$analysis_start_datetime, "POSIXct")
  expect_equal(parsed$analysis_sample_rate_khz, 2)
  expect_type(parsed$detection_n_validated, "integer")
  expect_type(parsed$localization_latitude, "double")
})

test_that("gpsdata parses datetime and coordinates", {
  raw <- tibble(
    row = 1L,
    deployment_code = "D1",
    datetime = "2025-04-25T00:00:00Z",
    latitude = "41.5",
    longitude = "-70.2"
  )

  parsed <- parse_pars_gpsdata(raw)

  expect_s3_class(parsed$datetime, "POSIXct")
  expect_equal(parsed$latitude, 41.5)
  expect_equal(parsed$longitude, -70.2)
})
