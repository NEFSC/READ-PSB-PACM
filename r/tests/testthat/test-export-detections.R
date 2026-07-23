# export_detections_table unnests pacm_data$analyses into one row per
# (analysis, day), flattening each day's <=1 mobile localization into
# latitude/longitude (blank for stationary days). A stationary analysis (no
# locations) and a mobile PARS analysis (one localized day) exercise both paths.
export_detections_fixture <- function () {
  tibble(
    submission_id = c("MAKARA", "USYRA_20260713"),
    deployment_id = c("NEFSC:STAT", "SYRACUSE:MOB"),
    analysis_id = c("NEFSC:STAT:RIWH", "SYRACUSE:MOB:RIWH"),
    species = c("RIWH", "RIWH"),
    detections = list(
      tibble(
        date = as.Date(c("2025-01-01", "2025-01-02")),
        presence = c("y", "n"),
        locations = list(NULL, NULL)
      ),
      tibble(
        date = as.Date("2025-03-01"),
        presence = "y",
        locations = list(tibble(latitude = 42.1, longitude = -68.3))
      )
    )
  )
}

test_that("the schema is submission_id .. presence, latitude, longitude", {
  x <- export_detections_table(export_detections_fixture())

  expect_equal(
    names(x),
    c("submission_id", "deployment_id", "analysis_id", "species", "date",
      "presence", "latitude", "longitude")
  )
})

test_that("there is one row per (analysis, day)", {
  fixture <- export_detections_fixture()
  x <- export_detections_table(fixture)

  expect_equal(nrow(x), sum(vapply(fixture$detections, nrow, integer(1))))
  expect_equal(nrow(x), 3)
})

test_that("stationary days have blank latitude/longitude", {
  x <- export_detections_table(export_detections_fixture())
  stat <- x[x$analysis_id == "NEFSC:STAT:RIWH", ]

  expect_true(all(is.na(stat$latitude)))
  expect_true(all(is.na(stat$longitude)))
})

test_that("a mobile localized day carries its latitude/longitude", {
  x <- export_detections_table(export_detections_fixture())
  mob <- x[x$analysis_id == "SYRACUSE:MOB:RIWH", ]

  expect_equal(mob$latitude, 42.1)
  expect_equal(mob$longitude, -68.3)
})

test_that("each detection row inherits its parent analysis's submission_id", {
  x <- export_detections_table(export_detections_fixture())

  expect_true(all(x$submission_id[x$deployment_id == "NEFSC:STAT"] == "MAKARA"))
  expect_true(all(x$submission_id[x$deployment_id == "SYRACUSE:MOB"] == "USYRA_20260713"))
})
