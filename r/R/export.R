# Flat CSV exports of the published PACM dataset
#
# One CSV per table (deployments, analyses, detections, tracks, sites,
# citations), projected from `pacm_data` - the same combined, deduplicated
# dataset the web app is built from. Each detection-bearing row carries a
# `submission_id`: the PARS submission that provided the data, or "MAKARA" for
# data from the Makara database. deployments/analyses carry it directly (threaded
# through pacm_names); detections inherit it; tracks join it from the deployment.
# sites/citations carry none - they are 1:1 derivable (site_id -> deployments,
# code -> analyses).
#
# Output goes to data/export/, a SIBLING of data/pacm/. scripts/copy-data.sh and
# scripts/deploy-data.sh act on data/pacm/*, so these exports are never published
# to the app or the GCS tarball.

# write a data frame to <dir>/<filename> using the pipeline's CSV conventions
# (blank for NA), creating the directory on first use. returns the path, so the
# caller can be a `format = "file"` target.
write_export_csv <- function (data, dir, filename) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }
  path <- file.path(dir, filename)
  write_csv(data, path, na = "")
  path
}

# deployments: pacm_data$deployments already IS the published deployment table
# (the pacm_names$deployments columns, submission_id among them). Project it
# verbatim, guaranteeing submission_id leads the file.
export_deployments_table <- function (deployments) {
  deployments |>
    relocate(submission_id)
}

# analyses: pacm_data$analyses carries a nested `detections` list-column (exported
# separately, one row per day). Drop it so the analyses file is flat; keep every
# other column, submission_id first.
export_analyses_table <- function (analyses) {
  analyses |>
    select(-any_of("detections")) |>
    relocate(submission_id)
}

# detections: one row per (analysis, day). Unnest the per-analysis `detections`
# and flatten each day's `locations` (<=1 mobile localization per day) into
# latitude/longitude columns - blank for stationary days. submission_id rides in
# from the parent analysis.
export_detections_table <- function (analyses) {
  first_or_na <- function (locations, column) {
    if (is.null(locations) || nrow(locations) == 0 ||
          !column %in% names(locations)) {
      return(NA_real_)
    }
    locations[[column]][[1]]
  }

  analyses |>
    select(submission_id, deployment_id, analysis_id, species, detections) |>
    unnest(detections) |>
    mutate(
      latitude = map_dbl(locations, first_or_na, column = "latitude"),
      longitude = map_dbl(locations, first_or_na, column = "longitude")
    ) |>
    select(
      submission_id, deployment_id, analysis_id, species, date, presence,
      latitude, longitude
    ) |>
    arrange(deployment_id, analysis_id, species, date)
}

# tracks: one row per ordered vertex of each track's line geometry. submission_id
# is not on the published tracks (they are 1:1 with deployments), so it is joined
# from the deployment. Returns a plain tibble (no sf geometry).
export_tracks_table <- function (tracks, deployments) {
  empty <- tibble(
    submission_id = character(),
    deployment_organization_code = character(),
    deployment_id = character(),
    track_id = character(),
    seq = integer(),
    longitude = double(),
    latitude = double()
  )
  if (is.null(tracks) || nrow(tracks) == 0) {
    return(empty)
  }

  attrs <- tracks |>
    st_drop_geometry() |>
    mutate(.row = row_number()) |>
    left_join(
      distinct(deployments, deployment_id, submission_id),
      by = "deployment_id"
    )

  coords <- st_coordinates(tracks) |>
    as_tibble()
  # st_coordinates returns X, Y and one or more L* index columns; the last L*
  # indexes the feature (row of `tracks`) for both LINESTRING and MULTILINESTRING
  feature_col <- names(coords)[ncol(coords)]

  coords |>
    transmute(longitude = X, latitude = Y, .row = .data[[feature_col]]) |>
    left_join(attrs, by = ".row") |>
    group_by(track_id) |>
    mutate(seq = row_number()) |>
    ungroup() |>
    select(
      submission_id, deployment_organization_code, deployment_id, track_id,
      seq, longitude, latitude
    )
}

# sites: a derived station grouping, 1:1 with deployments via site_id, so it
# carries no submission_id of its own (join to deployments.csv on site_id).
# pacm_data$sites already holds the published shape - project it verbatim.
export_sites_table <- function (sites) {
  sites
}

# citations: a reference table (code -> reference), resolvable to submissions via
# analyses.csv on `code`, so it carries no submission_id. pacm_data$citations
# already holds the published shape - project it verbatim.
export_citations_table <- function (citations) {
  citations
}

targets_export <- list(
  tar_target(export_dir, "data/export"),

  tar_target(
    export_deployments_file,
    write_export_csv(
      export_deployments_table(pacm_data$deployments),
      export_dir,
      "deployments.csv"
    ),
    format = "file"
  ),

  tar_target(
    export_analyses_file,
    write_export_csv(
      export_analyses_table(pacm_data$analyses),
      export_dir,
      "analyses.csv"
    ),
    format = "file"
  ),

  tar_target(
    export_detections_file,
    write_export_csv(
      export_detections_table(pacm_data$analyses),
      export_dir,
      "detections.csv"
    ),
    format = "file"
  ),

  tar_target(
    export_tracks_file,
    write_export_csv(
      export_tracks_table(pacm_data$tracks, pacm_data$deployments),
      export_dir,
      "tracks.csv"
    ),
    format = "file"
  ),

  tar_target(
    export_sites_file,
    write_export_csv(
      export_sites_table(pacm_data$sites),
      export_dir,
      "sites.csv"
    ),
    format = "file"
  ),

  tar_target(
    export_citations_file,
    write_export_csv(
      export_citations_table(pacm_data$citations),
      export_dir,
      "citations.csv"
    ),
    format = "file"
  ),

  # convenience aggregate: `tar_make(export)` builds all six CSVs at once
  tar_target(
    export,
    c(
      export_deployments_file,
      export_analyses_file,
      export_detections_file,
      export_tracks_file,
      export_sites_file,
      export_citations_file
    )
  )
)
