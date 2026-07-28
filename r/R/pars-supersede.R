# resolve supersession across submissions
#
# every entity table is built as one row per (entity, submission), so one
# resolver serves deployments, analyses and tracks alike: keep the row from the
# submission with the latest submission_date, report the rest.
#
# this removes published data, so it refuses to guess. two DIFFERENT submissions
# claiming one entity on the same date have no winner and stop the build. two
# rows for one entity from the SAME submission are a different thing - one
# submission legitimately producing two rows for an id, as CVOWC does for BLWH -
# and pass through untouched, for the caller's uniqueness assertion to catch.

PARS_SUPERSEDED_COLUMNS <- c(
  "entity", "entity_id", "superseded_submission_id", "superseded_date",
  "superseding_submission_id", "superseding_date"
)

pars_superseded_empty <- function () {
  tibble(
    entity = character(),
    entity_id = character(),
    superseded_submission_id = character(),
    superseded_date = as.Date(character()),
    superseding_submission_id = character(),
    superseding_date = as.Date(character())
  )
}

# `x` is one row per (entity, submission) carrying `submission_id`; `id_col`
# names the entity id column; `entity` labels the report; `submissions` is the
# manifest. returns list(current, superseded), where `superseded` keeps the
# losing rows' own columns so the caller can compare coverage against the winner
pars_supersede <- function (x, id_col, entity, submissions) {
  entity_label <- entity

  if (is.null(x) || nrow(x) == 0) {
    return(list(current = x, superseded = pars_superseded_empty()))
  }

  if (!"submission_id" %in% names(x)) {
    stop(
      "supersession: ", entity_label,
      " table has no submission_id column; it must be built with ",
      "submission_id as a grouping variable"
    )
  }

  unknown <- sort(unique(setdiff(x$submission_id, submissions$submission_id)))
  if (length(unknown) > 0) {
    stop(
      "supersession: submission_id(s) absent from the manifest: ",
      paste(unknown, collapse = ", ")
    )
  }

  keys <- tibble(
    entity_id = as.character(x[[id_col]]),
    submission_id = x$submission_id,
    submission_date = submissions$submission_date[
      match(x$submission_id, submissions$submission_id)
    ]
  ) |>
    mutate(winning_date = max(submission_date), .by = entity_id)

  tied <- keys |>
    filter(submission_date == winning_date) |>
    summarise(
      n_submissions = n_distinct(submission_id),
      submissions = paste(sort(unique(submission_id)), collapse = ", "),
      .by = entity_id
    ) |>
    filter(n_submissions > 1)

  if (nrow(tied) > 0) {
    stop(
      "supersession: ", entity_label,
      " claimed by two submissions with the same submission_date, so there is ",
      "no winner - ",
      paste0(tied$entity_id, " (", tied$submissions, ")", collapse = "; ")
    )
  }

  winners <- keys$submission_date == keys$winning_date
  loser_keys <- keys[!winners, ]

  winning_by_entity <- keys[winners, ] |>
    distinct(
      entity_id,
      superseding_submission_id = submission_id,
      superseding_date = submission_date
    )

  superseded <- x[!winners, ] |>
    select(-any_of("submission_id")) |>
    mutate(
      entity = entity_label,
      entity_id = loser_keys$entity_id,
      superseded_submission_id = loser_keys$submission_id,
      superseded_date = loser_keys$submission_date
    ) |>
    left_join(winning_by_entity, by = "entity_id") |>
    relocate(all_of(PARS_SUPERSEDED_COLUMNS))

  list(
    current = x[winners, ],
    superseded = superseded
  )
}

PARS_SUPERSEDED_SUMMARY_DEFAULTS <- list(
  entity = NA_character_,
  entity_id = NA_character_,
  organization_code = NA_character_,
  superseded_submission_id = NA_character_,
  superseded_date = as.Date(NA),
  superseding_submission_id = NA_character_,
  superseding_date = as.Date(NA),
  # only the entities with a coverage measure carry this; a deployment is a
  # single record, so there is nothing to compare
  coverage_reduced = NA
)

# combine the per-entity reports into one review surface.
#
# a correct supersession is invisible by design - it removes published data
# without erroring - so an accidentally reused deployment_code looks exactly
# like an intended update. this table is the thing to read at intake.
pars_superseded_summary <- function (...) {
  columns <- names(PARS_SUPERSEDED_SUMMARY_DEFAULTS)

  parts <- list(...) |>
    map(function (p) {
      if (is.null(p)) {
        return(NULL)
      }
      if (inherits(p, "sf")) {
        p <- st_drop_geometry(p)
      }

      for (col in setdiff(columns, names(p))) {
        p[[col]] <- rep(PARS_SUPERSEDED_SUMMARY_DEFAULTS[[col]], nrow(p))
      }

      select(p, all_of(columns))
    })

  x <- bind_rows(parts) |>
    arrange(entity, entity_id)

  # a submitter legitimately re-scoping an entity is indistinguishable from one
  # who under-sent, so this warns rather than failing. warning() rather than
  # log_warn() so it survives into tar_meta(fields = "warnings") instead of only
  # reaching the console of whoever happened to run the build
  reduced <- filter(x, coalesce(coverage_reduced, FALSE))
  if (nrow(reduced) > 0) {
    warning(
      "PARS supersession reduced coverage for ", nrow(reduced), " entit",
      if (nrow(reduced) == 1) "y: " else "ies: ",
      paste(reduced$entity_id, collapse = ", ")
    )
  }

  x
}

# analysis_id is {deployment_org}:{deployment_code}:{species} - it carries the
# DEPLOYMENT's organization, not the analyst's. so two organizations analysing
# one deployment for one species collide, and that pattern is supported (JASCO
# analyses DFO's recorders). a second analyst is a conflict, not a newer version
# of the same analysis, so date-ordering must never silently delete one
# analyst's work: report it instead, and let a human decide
pars_analysis_owner_conflicts <- function (analyses) {
  analyses |>
    summarise(
      n_owners = n_distinct(analysis_organization_code),
      owners = paste(sort(unique(analysis_organization_code)), collapse = ", "),
      submissions = paste(sort(unique(submission_id)), collapse = ", "),
      .by = analysis_id
    ) |>
    filter(n_owners > 1)
}

# resolve analyses, guarding the cross-organization case first and flagging a
# winner that covers less than the analysis it replaced. narrowing is a warning
# rather than an error because a submitter legitimately re-scoping an analysis
# looks identical to one who under-sent - only a human can tell them apart
pars_analyses_supersede <- function (analyses, submissions) {
  conflicts <- pars_analysis_owner_conflicts(analyses)
  if (nrow(conflicts) > 0) {
    stop(
      "supersession: analysis claimed by more than one analysis organization, ",
      "which is a conflict rather than a newer version - ",
      paste0(
        conflicts$analysis_id, " (organizations: ", conflicts$owners,
        "; submissions: ", conflicts$submissions, ")",
        collapse = "; "
      )
    )
  }

  resolved <- pars_supersede(analyses, "analysis_id", "analysis", submissions)

  if (nrow(resolved$superseded) == 0) {
    resolved$superseded <- resolved$superseded |>
      mutate(coverage_reduced = logical(0))
    return(resolved)
  }

  winners <- resolved$current |>
    transmute(
      entity_id = as.character(analysis_id),
      superseding_n_detections = n_detections,
      superseding_start_date = analysis_start_date,
      superseding_end_date = analysis_end_date
    )

  resolved$superseded <- resolved$superseded |>
    rename(
      superseded_n_detections = n_detections,
      superseded_start_date = analysis_start_date,
      superseded_end_date = analysis_end_date
    ) |>
    left_join(winners, by = "entity_id") |>
    mutate(
      coverage_reduced =
        superseding_n_detections < superseded_n_detections |
          superseding_start_date > superseded_start_date |
          superseding_end_date < superseded_end_date
    )

  resolved
}

# resolve tracks. a track is replaced WHOLE - a submitter sending a
# supplementary month of positions rather than the complete track loses the
# earlier months - so the same coverage flag applies here, measured in vertices
# and span rather than detection days
pars_tracks_supersede <- function (tracks, submissions) {
  resolved <- pars_supersede(tracks, "track_id", "track", submissions)

  if (nrow(resolved$superseded) == 0) {
    resolved$superseded <- resolved$superseded |>
      mutate(coverage_reduced = logical(0))
    return(resolved)
  }

  winners <- resolved$current |>
    st_drop_geometry() |>
    transmute(
      entity_id = as.character(track_id),
      superseding_n_positions = map_int(positions, nrow),
      superseding_start_datetime = start_datetime,
      superseding_end_datetime = end_datetime
    )

  resolved$superseded <- resolved$superseded |>
    mutate(superseded_n_positions = map_int(positions, nrow)) |>
    rename(
      superseded_start_datetime = start_datetime,
      superseded_end_datetime = end_datetime
    ) |>
    left_join(winners, by = "entity_id") |>
    mutate(
      coverage_reduced =
        superseding_n_positions < superseded_n_positions |
          superseding_start_datetime > superseded_start_datetime |
          superseding_end_datetime < superseded_end_datetime
    )

  resolved
}
