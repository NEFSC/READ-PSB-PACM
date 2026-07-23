source("packages.R")

pars_manifest <- read_csv("data-raw/pars/submissions.csv", show_col_types = FALSE)

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

  tar_target(pars_deployments, {
    x <- pars_deployments_table(pars_metadata)

    stopifnot(
      all(!is.na(x$organization_code)),
      anyDuplicated(x$deployment_id) == 0
    )

    x
  }),
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

  tar_target(pars_analyses, {
    x <- pars_analyses_table(pars_detectiondata, pars_deployments)

    stopifnot(
      all(!is.na(x$deployment_id)),
      anyDuplicated(x$analysis_id) == 0
    )

    tabyl(x, species)
    tabyl(x, detection_method)

    x
  }),
  # no PARS submission has gpsdata yet, so these are NULL until a mobile
  # platform is submitted; the path is covered by a glider fixture in tests
  tar_target(pars_tracks, {
    x <- pars_tracks_table(pars_gpsdata, pars_deployments)

    if (!is.null(x)) {
      stopifnot(
        all(x$deployment_id %in% pars_deployments$deployment_id),
        all(!duplicated(x$track_id)),
        all(!duplicated(x$deployment_id))
      )
    }

    x
  }),
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
