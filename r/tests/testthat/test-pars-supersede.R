# supersession removes published data, so the resolver has two jobs: pick the
# latest submission per entity, and refuse to guess when it cannot. every input
# is one row per (entity, submission), which is what lets deployments, analyses
# and tracks share one resolver.

sub_dates <- function (...) {
  dots <- c(...)
  tibble(
    submission_id = names(dots),
    submission_date = as.Date(unname(dots))
  )
}

entity_rows <- function (...) {
  ids <- c(...)
  tibble(
    deployment_id = unname(ids),
    submission_id = names(ids),
    payload = seq_along(ids)
  )
}

test_that("a frame with no duplicate ids round-trips unchanged", {
  x <- entity_rows(A = "ORG:D1", B = "ORG:D2")
  subs <- sub_dates(A = "2025-01-01", B = "2025-02-01")

  out <- pars_supersede(x, "deployment_id", "deployment", subs)

  expect_equal(out$current, x)
  expect_equal(nrow(out$superseded), 0)
})

test_that("the later submission wins and the earlier is reported", {
  x <- entity_rows(A = "ORG:D1", B = "ORG:D1")
  subs <- sub_dates(A = "2025-01-01", B = "2025-02-01")

  out <- pars_supersede(x, "deployment_id", "deployment", subs)

  expect_equal(nrow(out$current), 1)
  expect_equal(out$current$submission_id, "B")
  expect_equal(nrow(out$superseded), 1)
  expect_equal(out$superseded$superseded_submission_id, "A")
  expect_equal(out$superseded$superseding_submission_id, "B")
})

test_that("submission order in the frame does not decide the winner", {
  # B first, so a naive slice would keep the wrong row
  x <- entity_rows(B = "ORG:D1", A = "ORG:D1")
  subs <- sub_dates(A = "2025-01-01", B = "2025-02-01")

  out <- pars_supersede(x, "deployment_id", "deployment", subs)

  expect_equal(out$current$submission_id, "B")
})

test_that("the report carries both dates and the entity label", {
  x <- entity_rows(A = "ORG:D1", B = "ORG:D1")
  subs <- sub_dates(A = "2025-01-01", B = "2025-02-01")

  out <- pars_supersede(x, "deployment_id", "deployment", subs)

  expect_equal(out$superseded$entity, "deployment")
  expect_equal(out$superseded$entity_id, "ORG:D1")
  expect_equal(out$superseded$superseded_date, as.Date("2025-01-01"))
  expect_equal(out$superseded$superseding_date, as.Date("2025-02-01"))
})

test_that("a three-deep chain keeps only the newest and reports both losers", {
  x <- entity_rows(A = "ORG:D1", B = "ORG:D1", C = "ORG:D1")
  subs <- sub_dates(A = "2025-01-01", B = "2025-02-01", C = "2025-03-01")

  out <- pars_supersede(x, "deployment_id", "deployment", subs)

  expect_equal(out$current$submission_id, "C")
  expect_equal(nrow(out$superseded), 2)
  expect_setequal(out$superseded$superseded_submission_id, c("A", "B"))
  # both losers point at the surviving submission, not at each other
  expect_equal(unique(out$superseded$superseding_submission_id), "C")
})

test_that("entities are resolved independently of each other", {
  x <- bind_rows(
    entity_rows(A = "ORG:D1", B = "ORG:D1"),
    entity_rows(A = "ORG:D2")
  )
  subs <- sub_dates(A = "2025-01-01", B = "2025-02-01")

  out <- pars_supersede(x, "deployment_id", "deployment", subs)

  expect_equal(nrow(out$current), 2)
  expect_setequal(out$current$deployment_id, c("ORG:D1", "ORG:D2"))
  # D2 is only in A, so A survives for D2 while losing D1
  expect_equal(
    out$current$submission_id[out$current$deployment_id == "ORG:D2"], "A"
  )
})

test_that("two different submissions on the same date is an error", {
  x <- entity_rows(A = "ORG:D1", B = "ORG:D1")
  subs <- sub_dates(A = "2025-01-01", B = "2025-01-01")

  expect_error(
    pars_supersede(x, "deployment_id", "deployment", subs), "ORG:D1"
  )
})

test_that("the same-date error names both submissions", {
  x <- entity_rows(A = "ORG:D1", B = "ORG:D1")
  subs <- sub_dates(A = "2025-01-01", B = "2025-01-01")

  err <- expect_error(
    pars_supersede(x, "deployment_id", "deployment", subs)
  )

  expect_match(conditionMessage(err), "A")
  expect_match(conditionMessage(err), "B")
})

test_that("duplicate ids within ONE submission pass through untouched", {
  # the CVOWC case: one submission legitimately produces two rows sharing an
  # analysis_id. a date cannot break that tie, so the resolver must not try -
  # the caller's anyDuplicated backstop is what catches it
  x <- tibble(
    deployment_id = c("ORG:D1", "ORG:D1"),
    submission_id = c("A", "A"),
    payload = 1:2
  )
  subs <- sub_dates(A = "2025-01-01")

  out <- pars_supersede(x, "deployment_id", "deployment", subs)

  expect_equal(nrow(out$current), 2)
  expect_equal(nrow(out$superseded), 0)
})

test_that("a submission missing from the manifest is an error", {
  x <- entity_rows(A = "ORG:D1", ZZZ = "ORG:D2")
  subs <- sub_dates(A = "2025-01-01")

  expect_error(pars_supersede(x, "deployment_id", "deployment", subs), "ZZZ")
})

test_that("an empty frame yields an empty report with the report columns", {
  x <- entity_rows()[0, ]
  subs <- sub_dates(A = "2025-01-01")

  out <- pars_supersede(x, "deployment_id", "deployment", subs)

  expect_equal(nrow(out$current), 0)
  expect_equal(nrow(out$superseded), 0)
  expect_true(all(
    c("entity", "entity_id", "superseded_submission_id", "superseded_date",
      "superseding_submission_id", "superseding_date") %in%
      names(out$superseded)
  ))
})

test_that("NULL input yields NULL current and an empty report", {
  out <- pars_supersede(NULL, "deployment_id", "deployment", sub_dates())

  expect_null(out$current)
  expect_equal(nrow(out$superseded), 0)
})

test_that("an sf frame keeps its geometry and class through resolution", {
  # tracks arrive as sf, so the resolver must not silently drop the geometry
  # column or demote the frame to a plain tibble
  line <- function (x) {
    sf::st_sfc(sf::st_linestring(matrix(c(-70, 41, x, 42), 2, 2, byrow = TRUE)),
               crs = 4326)
  }
  x <- sf::st_as_sf(tibble(
    track_id = c("ORG:D1:TRACK", "ORG:D1:TRACK"),
    submission_id = c("A", "B"),
    geometry = c(line(-70.5), line(-71.5))
  ))
  subs <- sub_dates(A = "2025-01-01", B = "2025-02-01")

  out <- pars_supersede(x, "track_id", "track", subs)

  expect_s3_class(out$current, "sf")
  expect_equal(nrow(out$current), 1)
  expect_equal(out$current$submission_id, "B")
  expect_equal(nrow(sf::st_coordinates(out$current)), 2)
  # the loser's geometry survives, so vertex counts are comparable
  expect_equal(nrow(sf::st_coordinates(out$superseded)), 2)
})

test_that("the losing rows keep their own columns so coverage is computable", {
  x <- entity_rows(A = "ORG:D1", B = "ORG:D1")
  subs <- sub_dates(A = "2025-01-01", B = "2025-02-01")

  out <- pars_supersede(x, "deployment_id", "deployment", subs)

  # payload came from the losing row, not the winner
  expect_equal(out$superseded$payload, 1)
})

# summary table --------------------------------------------------------------
#
# the three per-entity reports are combined into one review surface, because a
# correct supersession is otherwise invisible: it silently removes published
# data, and an accidentally reused deployment_code looks exactly the same

superseded_fixture <- function (entity, entity_id, ..., organization_code = "ORG") {
  tibble(
    entity = entity,
    entity_id = entity_id,
    organization_code = organization_code,
    superseded_submission_id = "A",
    superseded_date = as.Date("2025-01-01"),
    superseding_submission_id = "B",
    superseding_date = as.Date("2025-06-01"),
    ...
  )
}

test_that("nothing superseded yields an empty frame with the full column set", {
  x <- pars_superseded_summary(
    pars_superseded_empty(), pars_superseded_empty(), pars_superseded_empty()
  )

  expect_equal(nrow(x), 0)
  expect_equal(
    names(x),
    c("entity", "entity_id", "organization_code", "superseded_submission_id",
      "superseded_date", "superseding_submission_id", "superseding_date",
      "coverage_reduced")
  )
})

test_that("one of each entity produces one row each", {
  # the narrowed analysis warns; that is asserted on its own below
  x <- suppressWarnings(pars_superseded_summary(
    superseded_fixture("deployment", "ORG:D1"),
    superseded_fixture("analysis", "ORG:D1:RIWH", coverage_reduced = TRUE),
    superseded_fixture("track", "ORG:D1:TRACK", coverage_reduced = FALSE)
  ))

  expect_equal(nrow(x), 3)
  expect_setequal(x$entity, c("deployment", "analysis", "track"))
  expect_equal(unique(x$organization_code), "ORG")
})

test_that("rows are ordered by entity then id so builds diff cleanly", {
  x <- pars_superseded_summary(
    superseded_fixture("track", "ORG:D2:TRACK", coverage_reduced = FALSE),
    superseded_fixture("analysis", "ORG:D2:RIWH", coverage_reduced = FALSE),
    superseded_fixture("analysis", "ORG:D1:RIWH", coverage_reduced = FALSE)
  )

  expect_equal(x$entity, c("analysis", "analysis", "track"))
  expect_equal(x$entity_id, c("ORG:D1:RIWH", "ORG:D2:RIWH", "ORG:D2:TRACK"))
})

test_that("a deployment has no coverage measure, so its flag is NA", {
  x <- pars_superseded_summary(
    superseded_fixture("deployment", "ORG:D1"),
    pars_superseded_empty(),
    pars_superseded_empty()
  )

  expect_true(is.na(x$coverage_reduced))
})

test_that("reduced coverage is warned about rather than failing the build", {
  expect_warning(
    pars_superseded_summary(
      pars_superseded_empty(),
      superseded_fixture("analysis", "ORG:D1:RIWH", coverage_reduced = TRUE),
      pars_superseded_empty()
    ),
    "ORG:D1:RIWH"
  )
})

test_that("unreduced coverage warns about nothing", {
  expect_no_warning(
    pars_superseded_summary(
      pars_superseded_empty(),
      superseded_fixture("analysis", "ORG:D1:RIWH", coverage_reduced = FALSE),
      pars_superseded_empty()
    )
  )
})

test_that("an sf track report is flattened into the summary", {
  line <- sf::st_sfc(
    sf::st_linestring(matrix(c(-70, 41, -71, 42), 2, 2, byrow = TRUE)), crs = 4326
  )
  tracks <- sf::st_as_sf(
    superseded_fixture("track", "ORG:D1:TRACK", coverage_reduced = FALSE) |>
      mutate(geometry = line)
  )

  x <- pars_superseded_summary(
    pars_superseded_empty(), pars_superseded_empty(), tracks
  )

  expect_equal(nrow(x), 1)
  expect_false(inherits(x, "sf"))
  expect_false("geometry" %in% names(x))
})
