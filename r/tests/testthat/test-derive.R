# characterization tests for the source-agnostic derivations lifted out of
# legacy.R. these pin the existing behaviour so the PARS path can reuse it
# and produce identical site ids and tracks.

stationary_deployments <- function(...) {
  rows <- bind_rows(...)
  mutate(rows, deployment_type = "STATIONARY")
}

deployment_row <- function(deployment_id, site, latitude, longitude,
                           organization_code = "ORG",
                           monitoring_start_datetime = as.POSIXct(
                             "2025-01-01", tz = "UTC"
                           )) {
  tibble(
    organization_code = organization_code,
    site = site,
    deployment_id = deployment_id,
    latitude = latitude,
    longitude = longitude,
    monitoring_start_datetime = monitoring_start_datetime,
    monitoring_end_datetime = monitoring_start_datetime + 86400
  )
}

# derive_sites ---------------------------------------------------------------

test_that("a site with one deployment gets an unversioned site_id", {
  deployments <- stationary_deployments(
    deployment_row("ORG:D1", "SITE_A", 41.0, -70.0)
  )

  sites <- derive_sites(deployments)

  expect_equal(nrow(sites), 1)
  expect_equal(as.character(sites$site_id), "ORG:SITE_A")
  expect_equal(sites$site_version, 1)
  expect_equal(sites$n_deployments, 1L)
})

test_that("deployments within 10 km stay a single site version", {
  # ~5 km apart
  deployments <- stationary_deployments(
    deployment_row("ORG:D1", "SITE_A", 41.00, -70.0,
                   monitoring_start_datetime = as.POSIXct("2025-01-01", tz = "UTC")),
    deployment_row("ORG:D2", "SITE_A", 41.045, -70.0,
                   monitoring_start_datetime = as.POSIXct("2025-02-01", tz = "UTC"))
  )

  sites <- derive_sites(deployments)

  expect_equal(nrow(sites), 1)
  expect_equal(as.character(sites$site_id), "ORG:SITE_A")
  expect_equal(sites$n_deployments, 2L)
})

test_that("a move beyond 10 km splits the site into versioned ids", {
  # ~55 km apart
  deployments <- stationary_deployments(
    deployment_row("ORG:D1", "SITE_A", 41.0, -70.0,
                   monitoring_start_datetime = as.POSIXct("2025-01-01", tz = "UTC")),
    deployment_row("ORG:D2", "SITE_A", 41.5, -70.0,
                   monitoring_start_datetime = as.POSIXct("2025-02-01", tz = "UTC"))
  )

  sites <- derive_sites(deployments)

  expect_equal(nrow(sites), 2)
  expect_setequal(as.character(sites$site_id), c("ORG:SITE_A:1", "ORG:SITE_A:2"))
  expect_equal(sites$n_deployments, c(1L, 1L))
})

test_that("site coordinates come from the first deployment of each version", {
  deployments <- stationary_deployments(
    deployment_row("ORG:D1", "SITE_A", 41.0, -70.0,
                   monitoring_start_datetime = as.POSIXct("2025-01-01", tz = "UTC")),
    deployment_row("ORG:D2", "SITE_A", 41.045, -70.0,
                   monitoring_start_datetime = as.POSIXct("2025-02-01", tz = "UTC"))
  )

  sites <- derive_sites(deployments)

  expect_equal(sites$site_latitude, 41.0)
  expect_equal(sites$site_longitude, -70.0)
})

test_that("deployments are ordered by monitoring start, not input order", {
  deployments <- stationary_deployments(
    deployment_row("ORG:LATER", "SITE_A", 41.5, -70.0,
                   monitoring_start_datetime = as.POSIXct("2025-06-01", tz = "UTC")),
    deployment_row("ORG:EARLIER", "SITE_A", 41.0, -70.0,
                   monitoring_start_datetime = as.POSIXct("2025-01-01", tz = "UTC"))
  )

  sites <- derive_sites(deployments)

  # the earlier deployment anchors version 1
  first_version <- sites[sites$site_version == 1, ]
  expect_equal(first_version$site_latitude, 41.0)
})

test_that("mobile deployments do not produce sites", {
  deployments <- bind_rows(
    mutate(deployment_row("ORG:D1", "SITE_A", 41.0, -70.0),
           deployment_type = "STATIONARY"),
    mutate(deployment_row("ORG:D2", "SITE_B", 42.0, -70.0),
           deployment_type = "MOBILE")
  )

  sites <- derive_sites(deployments)

  expect_equal(nrow(sites), 1)
  expect_equal(sites$site, "SITE_A")
})

test_that("each site keeps its nested deployments", {
  deployments <- stationary_deployments(
    deployment_row("ORG:D1", "SITE_A", 41.0, -70.0),
    deployment_row("ORG:D2", "SITE_B", 42.0, -71.0)
  )

  sites <- derive_sites(deployments)

  expect_equal(nrow(sites), 2)
  expect_true("deployments" %in% names(sites))
  expect_setequal(
    unlist(lapply(sites$deployments, function (d) d$deployment_id)),
    c("ORG:D1", "ORG:D2")
  )
})

test_that("separate sites are clustered independently", {
  deployments <- stationary_deployments(
    deployment_row("ORG:D1", "SITE_A", 41.0, -70.0),
    deployment_row("ORG:D2", "SITE_B", 45.0, -60.0)
  )

  sites <- derive_sites(deployments)

  expect_equal(nrow(sites), 2)
  expect_setequal(as.character(sites$site_id), c("ORG:SITE_A", "ORG:SITE_B"))
})

# derive_tracks --------------------------------------------------------------

track_positions <- function(deployment_code = "D1", n = 4,
                            start = as.POSIXct("2025-01-01 00:00:00", tz = "UTC"),
                            by_secs = 1800) {
  tibble(
    deployment_code = deployment_code,
    datetime = start + (seq_len(n) - 1) * by_secs,
    latitude = 41 + (seq_len(n) - 1) * 0.01,
    longitude = -70 + (seq_len(n) - 1) * 0.01
  )
}

track_deployments <- function(deployment_code = "D1") {
  tibble(
    organization_code = "ORG",
    deployment_id = paste0("ORG:", deployment_code),
    deployment_code = deployment_code
  )
}

test_that("positions are aggregated to the first fix in each hour", {
  # 4 positions 30 min apart spans 2 hours -> 2 vertices
  positions <- track_positions(n = 4, by_secs = 1800)

  tracks <- derive_tracks(positions, track_deployments())

  expect_equal(nrow(tracks), 1)
  expect_equal(nrow(sf::st_coordinates(tracks)), 2)
})

test_that("a track carries its start and end position and time", {
  positions <- track_positions(n = 4, by_secs = 3600)

  tracks <- derive_tracks(positions, track_deployments())

  expect_equal(tracks$start_latitude, 41.00)
  expect_equal(tracks$end_latitude, 41.03)
  expect_equal(tracks$start_datetime, positions$datetime[[1]])
  expect_equal(tracks$end_datetime, positions$datetime[[4]])
})

test_that("track_id is derived from the deployment id", {
  tracks <- derive_tracks(track_positions(), track_deployments())

  expect_equal(as.character(tracks$track_id), "ORG:D1:TRACK")
})

test_that("each deployment produces its own track", {
  positions <- bind_rows(
    track_positions("D1", n = 3, by_secs = 3600),
    track_positions("D2", n = 3, by_secs = 3600)
  )
  deployments <- bind_rows(track_deployments("D1"), track_deployments("D2"))

  tracks <- derive_tracks(positions, deployments)

  expect_equal(nrow(tracks), 2)
  expect_setequal(as.character(tracks$track_id), c("ORG:D1:TRACK", "ORG:D2:TRACK"))
})

test_that("tracks are multilinestrings", {
  tracks <- derive_tracks(track_positions(), track_deployments())

  expect_true(all(sf::st_geometry_type(tracks) == "MULTILINESTRING"))
})

test_that("a deployment appearing twice is rejected rather than silently duplicated", {
  deployments <- bind_rows(track_deployments("D1"), track_deployments("D1"))

  expect_error(derive_tracks(track_positions(), deployments), "duplicated")
})
