source("packages.R")

# read at pipeline-definition time because tar_map needs its values before the
# DAG exists. the `pars_submissions` target below reads the same file again, so
# that a manifest edit invalidates the supersession filters that depend on it
pars_manifest <- read_pars_submissions()

# re-load all submissions
# make_pars(pars_manifest$submission_id)
make_pars <- function (ids = NULL) {
  if (is.null(ids)) {
    tar_invalidate(starts_with("pars_sub_"))
  } else {
    tar_invalidate(any_of(paste0("pars_sub_", ids)))
  }

  tar_make(pars)
}

# targets ----------------------------------------------------------------

pars_targets <- tar_map(
  values = list(
    sub_id = pars_manifest$submission_id,
    sub_format = pars_manifest$format,
    sub_skip = pars_manifest$skip
  ),
  names = c(sub_id),
  tar_target(
    pars_sub,
    load_pars(sub_id, sub_format, sub_skip, pars_dir, pars_codes),
    cue = tar_cue(mode = "never")
  )
)

targets_pars <- list(
  tar_target(pars_dir, "data-raw/pars"),

  # file-tracked so that editing a submission_date invalidates the supersession
  # filters downstream. the pars_sub_* loads are unaffected - they take their
  # values from the definition-time read above and carry tar_cue(mode = "never")
  tar_target(pars_submissions_file, PARS_SUBMISSIONS_PATH, format = "file"),
  tar_target(pars_submissions, read_pars_submissions(pars_submissions_file)),

  pars_targets,
  tar_combine(
    pars,
    pars_targets,
    command = bind_rows(!!!.x)
  ),

  # the vendored mobile-platform constant must not drift from Makara
  tar_target(pars_platform_type_drift, {
    expected <- platform_types |>
      filter(deployment_type == "MOBILE") |>
      pull(platform_type)
    drift <- union(
      setdiff(expected, PARS_MOBILE_PLATFORM_TYPES),
      setdiff(PARS_MOBILE_PLATFORM_TYPES, expected)
    )
    if (length(drift) > 0) {
      log_warn(
        "PARS_MOBILE_PLATFORM_TYPES has drifted from platform_types: ",
        "{paste(drift, collapse = ', ')}"
      )
    }
    drift
  }),

  tar_target(pars_errors, {
    per_file <- pars |>
      select(id, metadata, detectiondata, gpsdata) |>
      pivot_longer(-id, names_to = "table", values_to = "file") |>
      filter(map_lgl(file, ~ !is.null(.))) |>
      mutate(errors = map(file, ~ .$errors[[1]])) |>
      select(id, table, errors) |>
      unnest(errors)

    cross_file <- pars |>
      select(id, errors) |>
      unnest(errors) |>
      mutate(table = "submission")

    bind_rows(per_file, cross_file, mutate(pars_referential, id = NA_character_))
  }),

  # global referential integrity over the combined pool: every
  # detection/gps deployment_code must exist in some submission's metadata, and
  # mobile<->gps expectations hold across submissions. this cannot be per-file,
  # because one submission may analyse another's deployments
  tar_target(pars_referential, {
    md <- mutate(pars_metadata, row = row_number())
    dd <- mutate(pars_detectiondata, row = row_number())
    gp <- if (is.null(pars_gpsdata)) NULL else mutate(pars_gpsdata, row = row_number())

    bind_rows(
      pars_referential_errors(md, dd, gp),
      pars_gpsdata_errors(md, gp)
    ) |>
      mutate(table = "referential")
  }),

  tar_target(pars_metadata, {
    pars |>
      select(id, metadata) |>
      unnest(metadata) |>
      select(submission_id = id, parsed) |>
      unnest(parsed) |>
      select(-row)
  }),
  tar_target(pars_detectiondata, {
    pars |>
      select(id, detectiondata) |>
      unnest(detectiondata) |>
      select(submission_id = id, parsed) |>
      unnest(parsed) |>
      select(-row)
  }),
  tar_target(pars_gpsdata, {
    x <- pars |>
      select(id, gpsdata) |>
      unnest(gpsdata)

    if (nrow(x) == 0) return(NULL)

    x |>
      select(submission_id = id, parsed) |>
      unnest(parsed) |>
      select(-row)
  }),

  # pars_metadata is one row per (deployment, submission), so resolving on
  # deployment_id keeps the latest version of each. pars_referential
  # deliberately keeps checking against the UNresolved pars_metadata: a
  # superseded deployment's code still exists in the winner, so orphan
  # detection is unaffected and detections keep resolving across submissions
  tar_target(pars_deployments_resolved, {
    x <- pars_deployments_table(pars_metadata)

    stopifnot(all(!is.na(x$organization_code)))

    pars_supersede(x, "deployment_id", "deployment", pars_submissions)
  }),
  tar_target(pars_deployments, {
    x <- pars_deployments_resolved$current

    # unreachable once supersession resolves; retained because it is what would
    # catch a resolver bug, and it is the same guard the other entities keep
    stopifnot(anyDuplicated(x$deployment_id) == 0)

    # pars_analyses_table joins detections to this table by bare
    # deployment_code, so the code must identify one deployment on its own
    pars_check_deployment_codes(x)

    x
  }),
  tar_target(
    pars_deployments_superseded, pars_deployments_resolved$superseded
  ),
  tar_target(pars_deployments_map, {
    pars_deployments |>
      filter(deployment_type == "STATIONARY") |>
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
      mapview::mapview(zcol = "organization_code", layer.name = "deployments")
  }),
  tar_target(pars_deployments_pacm, {
    pars_deployments |>
      left_join(
        pars_sites |>
          unnest(deployments) |>
          select(site_id, deployment_id),
        by = "deployment_id"
      ) |>
      rename(deployment_organization_code = organization_code) |>
      select(all_of(pacm_names$deployments))
  }),

  # site derivation is shared with the legacy path, which is what keeps
  # site ids identical across the migration
  tar_target(pars_sites, derive_sites(pars_deployments)),
  tar_target(pars_sites_map, {
    pars_sites |>
      select(-deployments) |>
      st_as_sf(coords = c("site_longitude", "site_latitude"), crs = 4326) |>
      mapview::mapview(
        label = "site_id", zcol = "n_deployments", layer.name = "# deployments"
      )
  }),
  tar_target(pars_sites_pacm, {
    pars_sites |>
      rename(deployment_organization_code = organization_code) |>
      select(all_of(pacm_names$sites))
  }),

  # pars_analyses_table already nests detections with submission_id among the
  # analysis keys, so its output is one row per (analysis, submission) and only
  # needs resolving. the cross-organization guard lives in there too
  tar_target(pars_analyses_resolved, {
    x <- pars_analyses_table(pars_detectiondata, pars_deployments)

    stopifnot(all(!is.na(x$deployment_id)))

    pars_analyses_supersede(x, pars_submissions)
  }),
  tar_target(pars_analyses, {
    x <- pars_analyses_resolved$current

    # kept AFTER resolution: two analyses of one deployment and species within a
    # single submission tie by date, so the resolver passes them through and
    # this is what rejects them - exactly as before supersession existed
    stopifnot(anyDuplicated(x$analysis_id) == 0)

    tabyl(x, species)
    tabyl(x, detection_method)

    x
  }),
  tar_target(pars_analyses_superseded, pars_analyses_resolved$superseded),
  tar_target(pars_tracks_resolved, {
    x <- pars_tracks_table(pars_gpsdata, pars_deployments)

    pars_tracks_supersede(x, pars_submissions)
  }),
  tar_target(pars_tracks, {
    x <- pars_tracks_resolved$current

    # these hold only AFTER resolution now: pars_tracks_table deliberately emits
    # one row per (deployment, submission), so a resent track duplicates both
    # ids until the latest submission wins
    if (!is.null(x)) {
      stopifnot(
        all(x$deployment_id %in% pars_deployments$deployment_id),
        all(!duplicated(x$track_id)),
        all(!duplicated(x$deployment_id))
      )
    }

    x
  }),
  tar_target(pars_tracks_superseded, pars_tracks_resolved$superseded),
  tar_target(pars_tracks_pacm, {
    if (is.null(pars_tracks)) return(NULL)

    pars_tracks |>
      rename(deployment_organization_code = organization_code) |>
      select(all_of(pacm_names$tracks))
  }),

  # the citation reference table for the PARS source (code -> reference text),
  # minted from the submitted free-text analysis_citations. shape matches
  # makara_citations_pacm so both bind into pacm_data$citations
  tar_target(pars_citations_pacm, {
    pars_citation_codes(pars_analyses) |>
      select(code, reference)
  }),

  tar_target(pars_analyses_pacm, {
    # published `citations` holds reference *codes* that resolve against
    # pacm_data$citations. PARS analysis_citations is free-text prose, so mint a
    # code per distinct blob (pars_citations_pacm) and publish the code here
    codes <- pars_citation_codes(pars_analyses)

    pars_analyses |>
      left_join(
        codes, by = c("analysis_organization_code", "citations" = "reference")
      ) |>
      mutate(
        deployment_organization_code = organization_code,
        detections = map(
          detections, ~ select(., all_of(pacm_names$analyses_detections))
        ),
        citations = code
      ) |>
      select(all_of(pacm_names$analyses))
  }),

  # the review surface for supersession. read this at intake: a correct
  # supersession removes published data without erroring, so an accidentally
  # reused deployment_code looks exactly like an intended update
  tar_target(pars_superseded, pars_superseded_summary(
    pars_deployments_superseded,
    pars_analyses_superseded,
    pars_tracks_superseded
  )),

  # integrity gate: nothing reaches the published dataset unless the submission
  # validated cleanly and every cross-table reference resolves
  tar_target(pars_pacm, {
    tracks_ok <- is.null(pars_tracks_pacm) ||
      all(pars_tracks_pacm$deployment_id %in% pars_deployments_pacm$deployment_id)
    tracks_unique <- is.null(pars_tracks_pacm) ||
      !anyDuplicated(pars_tracks_pacm$track_id)

    stopifnot(
      nrow(pars_errors) == 0,
      all(!is.na(pars_deployments_pacm$deployment_organization_code)),
      all(na.omit(pars_deployments_pacm$site_id) %in% pars_sites_pacm$site_id),
      all(pars_analyses_pacm$deployment_id %in% pars_deployments_pacm$deployment_id),
      tracks_ok,
      !anyDuplicated(pars_sites_pacm$site_id),
      !anyDuplicated(pars_deployments_pacm$deployment_id),
      !anyDuplicated(pars_analyses_pacm$analysis_id),
      tracks_unique
    )

    list(
      sites = pars_sites_pacm,
      deployments = pars_deployments_pacm,
      analyses = pars_analyses_pacm,
      tracks = pars_tracks_pacm,
      citations = pars_citations_pacm
    )
  })
)
