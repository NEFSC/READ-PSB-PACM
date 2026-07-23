# export_tracks_table expands each track's MULTILINESTRING geometry into ordered
# vertices and joins submission_id from the deployment. Two tracks - one on a
# Makara deployment, one on a PARS (glider) deployment - exercise both
# attribution paths.
export_tracks_fixture <- function () {
  g1 <- sf::st_multilinestring(list(
    matrix(c(-70, 41, -70.5, 41.5, -71, 42), ncol = 2, byrow = TRUE)
  ))
  g2 <- sf::st_multilinestring(list(
    matrix(c(-68, 40, -68.2, 40.1), ncol = 2, byrow = TRUE)
  ))
  sf::st_as_sf(tibble(
    deployment_organization_code = c("NEFSC", "SYRACUSE"),
    deployment_id = c("NEFSC:MOB", "SYRACUSE:GLIDER"),
    track_id = c("NEFSC:MOB:TRACK", "SYRACUSE:GLIDER:TRACK"),
    geometry = sf::st_sfc(g1, g2, crs = 4326)
  ))
}

export_tracks_deployments_fixture <- function () {
  tibble(
    deployment_id = c("NEFSC:MOB", "SYRACUSE:GLIDER"),
    submission_id = c("MAKARA", "USYRA_20260713")
  )
}

test_that("the schema is submission_id, org, deployment_id, track_id, seq, lon, lat", {
  x <- export_tracks_table(
    export_tracks_fixture(), export_tracks_deployments_fixture()
  )

  expect_equal(
    names(x),
    c("submission_id", "deployment_organization_code", "deployment_id",
      "track_id", "seq", "longitude", "latitude")
  )
  expect_false(any(vapply(x, is.list, logical(1))))
})

test_that("each track's vertex count matches its geometry", {
  x <- export_tracks_table(
    export_tracks_fixture(), export_tracks_deployments_fixture()
  )

  expect_equal(dplyr::n_distinct(x$track_id), 2)
  expect_equal(sum(x$track_id == "NEFSC:MOB:TRACK"), 3)
  expect_equal(sum(x$track_id == "SYRACUSE:GLIDER:TRACK"), 2)
})

test_that("vertices are numbered in order within each track", {
  x <- export_tracks_table(
    export_tracks_fixture(), export_tracks_deployments_fixture()
  )
  t1 <- x[x$track_id == "NEFSC:MOB:TRACK", ]

  expect_equal(t1$seq, 1:3)
  # first vertex is the first coordinate of g1
  expect_equal(t1$longitude[[1]], -70)
  expect_equal(t1$latitude[[1]], 41)
})

test_that("submission_id is joined from the deployment (MAKARA vs PARS)", {
  x <- export_tracks_table(
    export_tracks_fixture(), export_tracks_deployments_fixture()
  )

  expect_true(all(x$submission_id[x$track_id == "NEFSC:MOB:TRACK"] == "MAKARA"))
  expect_true(all(
    x$submission_id[x$track_id == "SYRACUSE:GLIDER:TRACK"] == "USYRA_20260713"
  ))
})

test_that("NULL or empty tracks yield a 0-row frame with the right columns", {
  empty <- export_tracks_table(NULL, export_tracks_deployments_fixture())

  expect_equal(nrow(empty), 0)
  expect_equal(
    names(empty),
    c("submission_id", "deployment_organization_code", "deployment_id",
      "track_id", "seq", "longitude", "latitude")
  )
})
