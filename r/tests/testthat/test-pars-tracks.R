# No PARS submission has yet included gpsdata (I-4): USYRA is entirely
# stationary. These fixtures use real positions from the guide's glider example
# (WHOI_MA-RI_202210_WE16) so the track path is exercised against realistic
# data rather than invented coordinates.

glider_positions <- function() {
  raw <- tibble::tribble(
    ~datetime,               ~latitude, ~longitude,
    "2022-10-27T14:27:05Z",  41.3187,   -70.9751,
    "2022-10-27T14:42:05Z",  41.3167,   -70.9740,
    "2022-10-27T15:12:05Z",  41.3127,   -70.9718,
    "2022-10-27T16:12:05Z",  41.3048,   -70.9676,
    "2022-10-27T17:12:05Z",  41.2961,   -70.9644,
    "2022-10-27T18:12:05Z",  41.2850,   -70.9680,
    "2022-10-27T19:12:05Z",  41.2747,   -70.9714,
    "2022-10-27T19:27:05Z",  41.2722,   -70.9731,
    "2022-10-27T20:12:05Z",  41.2642,   -70.9786,
    "2022-10-27T21:12:05Z",  41.2535,   -70.9858,
    "2022-10-27T22:12:05Z",  41.2478,   -70.9891,
    "2022-10-27T22:27:05Z",  41.2464,   -70.9893,
    "2022-10-27T23:12:05Z",  41.2421,   -70.9899,
    "2022-10-28T00:12:05Z",  41.2401,   -70.9925
  )
  tibble(
    submission_id = "GLIDER_SUB",
    deployment_code = "WHOI_MA-RI_202210_WE16",
    datetime = parse_pars_datetime(raw$datetime),
    latitude = raw$latitude,
    longitude = raw$longitude
  )
}

glider_deployments <- function() {
  tibble(
    organization_code = "WHOI",
    deployment_id = "WHOI:WHOI_MA-RI_202210_WE16",
    deployment_code = "WHOI_MA-RI_202210_WE16",
    deployment_type = "MOBILE"
  )
}

test_that("a mobile deployment produces one track", {
  tracks <- pars_tracks_table(glider_positions(), glider_deployments())

  expect_equal(nrow(tracks), 1)
})

test_that("track_id is derived from the deployment id", {
  tracks <- pars_tracks_table(glider_positions(), glider_deployments())

  expect_equal(
    as.character(tracks$track_id), "WHOI:WHOI_MA-RI_202210_WE16:TRACK"
  )
})

test_that("positions are thinned to the first fix in each hour", {
  # 14 positions spanning 11 distinct hours (14,15,16,17,18,19,20,21,22,23,00)
  tracks <- pars_tracks_table(glider_positions(), glider_deployments())

  expect_equal(nrow(sf::st_coordinates(tracks)), 11)
})

test_that("the track keeps its start and end position", {
  tracks <- pars_tracks_table(glider_positions(), glider_deployments())

  expect_equal(tracks$start_latitude, 41.3187)
  expect_equal(tracks$start_longitude, -70.9751)
  expect_equal(tracks$end_latitude, 41.2401)
  expect_equal(tracks$end_longitude, -70.9925)
})

test_that("the track spans the full position record", {
  positions <- glider_positions()
  tracks <- pars_tracks_table(positions, glider_deployments())

  expect_equal(tracks$start_datetime, min(positions$datetime))
  expect_equal(tracks$end_datetime, max(positions$datetime))
})

test_that("tracks are multilinestrings", {
  tracks <- pars_tracks_table(glider_positions(), glider_deployments())

  expect_true(all(sf::st_geometry_type(tracks) == "MULTILINESTRING"))
})

test_that("the geometry lies south of Martha's Vineyard, matching the source data", {
  tracks <- pars_tracks_table(glider_positions(), glider_deployments())
  coords <- sf::st_coordinates(tracks)

  expect_true(all(coords[, "Y"] > 41.2 & coords[, "Y"] < 41.4))
  expect_true(all(coords[, "X"] > -71.1 & coords[, "X"] < -70.9))
})

test_that("the track runs southwards, as the glider did", {
  tracks <- pars_tracks_table(glider_positions(), glider_deployments())

  expect_true(tracks$end_latitude < tracks$start_latitude)
})

test_that("each mobile deployment gets its own track", {
  positions <- bind_rows(
    glider_positions(),
    mutate(glider_positions(), deployment_code = "WHOI_SECOND", latitude = latitude + 1)
  )
  deployments <- bind_rows(
    glider_deployments(),
    tibble(
      organization_code = "WHOI",
      deployment_id = "WHOI:WHOI_SECOND",
      deployment_code = "WHOI_SECOND",
      deployment_type = "MOBILE"
    )
  )

  tracks <- pars_tracks_table(positions, deployments)

  expect_equal(nrow(tracks), 2)
  expect_equal(anyDuplicated(tracks$track_id), 0)
  expect_equal(anyDuplicated(tracks$deployment_id), 0)
})

test_that("every track belongs to a known deployment", {
  tracks <- pars_tracks_table(glider_positions(), glider_deployments())

  expect_true(all(tracks$deployment_id %in% glider_deployments()$deployment_id))
})

test_that("a submission with no gps positions produces no tracks", {
  # this is the USYRA case: entirely stationary, gpsdata.csv absent
  expect_null(pars_tracks_table(NULL, glider_deployments()))
})

test_that("an empty position table produces no tracks", {
  empty <- glider_positions()[0, ]

  expect_null(pars_tracks_table(empty, glider_deployments()))
})

test_that("extra columns on the position table do not disturb the track", {
  positions <- mutate(glider_positions(), stray_column = "ignore me")

  tracks <- pars_tracks_table(positions, glider_deployments())

  expect_equal(nrow(tracks), 1)
  expect_false("stray_column" %in% names(tracks))
})

# segmentation on effort gaps (T2.4) -----------------------------------------
#
# PARS gpsdata carries no effort flag, so a break in effort is visible only as
# an absence of positions. Without segmentation a track is drawn straight
# through port calls and off-effort transits.

segment_count <- function (tracks) {
  lengths(sf::st_geometry(tracks))
}

vertex_count <- function (tracks) {
  sum(vapply(
    sf::st_geometry(tracks)[[1]], nrow, numeric(1)
  ))
}

# shift a block of positions forward, leaving a hole of whole days.
#
# `from` must not fall between two positions that share an hour (rows 1-2, 7-8
# and 11-12 here), or the shift separates them and hourly thinning keeps an
# extra one - which would change the vertex count for reasons unrelated to
# segmentation
with_gap <- function (positions, gap_days, from = 9) {
  positions |>
    mutate(datetime = if_else(
      row_number() >= from, datetime + lubridate::days(gap_days), datetime
    ))
}

test_that("a continuously tracked deployment stays a single segment", {
  tracks <- pars_tracks_table(glider_positions(), glider_deployments())

  expect_equal(unname(segment_count(tracks)), 1)
})

test_that("a multi-day hole in the positions splits the track", {
  tracks <- pars_tracks_table(
    with_gap(glider_positions(), gap_days = 3), glider_deployments()
  )

  expect_equal(unname(segment_count(tracks)), 2)
})

test_that("two holes produce three segments", {
  positions <- glider_positions() |>
    with_gap(gap_days = 3, from = 6) |>
    with_gap(gap_days = 6, from = 10)

  tracks <- pars_tracks_table(positions, glider_deployments())

  expect_equal(unname(segment_count(tracks)), 3)
})

test_that("segmentation keeps every position as a vertex", {
  positions <- with_gap(glider_positions(), gap_days = 3)
  # 14 raw positions thin to 11 hourly ones, and splitting must not drop any
  ungapped <- pars_tracks_table(glider_positions(), glider_deployments())
  gapped <- pars_tracks_table(positions, glider_deployments())

  expect_equal(vertex_count(gapped), vertex_count(ungapped))
})

test_that("a long gap within consecutive days does not split the track", {
  # a break in recording is not a break in effort: towed array legs contain
  # gaps of up to 26.7 hours, while genuine leg boundaries always skip a day
  positions <- glider_positions() |>
    mutate(datetime = if_else(
      row_number() >= 8, datetime + lubridate::hours(20), datetime
    ))

  tracks <- pars_tracks_table(positions, glider_deployments())

  expect_equal(unname(segment_count(tracks)), 1)
})

test_that("a segmented track keeps one row and one id per deployment", {
  tracks <- pars_tracks_table(
    with_gap(glider_positions(), gap_days = 3), glider_deployments()
  )

  expect_equal(nrow(tracks), 1)
  expect_equal(tracks$track_id, "WHOI:WHOI_MA-RI_202210_WE16:TRACK")
  expect_s3_class(sf::st_geometry(tracks), "sfc_MULTILINESTRING")
})

test_that("a segment holding a single position is dropped, not fatal", {
  # one stray position days after the rest cannot form a line segment
  positions <- bind_rows(
    glider_positions(),
    tibble(
      submission_id = "GLIDER_SUB",
      deployment_code = "WHOI_MA-RI_202210_WE16",
      datetime = parse_pars_datetime("2022-11-15T12:00:00Z"),
      latitude = 41.0, longitude = -70.5
    )
  )

  tracks <- pars_tracks_table(positions, glider_deployments())

  expect_equal(nrow(tracks), 1)
  expect_equal(unname(segment_count(tracks)), 1)
})
