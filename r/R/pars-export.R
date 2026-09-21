# Per-organization export of the PARS dataset in PARS template format
#
# Writes metadata.csv, detectiondata.csv and gpsdata.csv for one organization,
# with the PARS submission template columns plus submission_id, from the parsed
# submission tables (pars_metadata, pars_detectiondata, pars_gpsdata). Not a
# target: call it interactively after `tar_make(pars)`.

# format a parsed PARS datetime back to the template's ISO 8601 form with an
# explicit UTC offset (the loader parsed everything to UTC)
format_pars_datetime <- function (x) {
  if_else(is.na(x), NA_character_, format(x, "%Y-%m-%dT%H:%M:%S+00:00", tz = "UTC"))
}

# export every PARS row that belongs to `organization_code`, either because the
# organization deployed the recorder (deployment_organization_code in metadata)
# or because it ran the analysis (analysis_organization_code in detectiondata).
# metadata for another organization's deployments is included when this
# organization analyzed them, so every detectiondata row has its deployment.
# gpsdata follows the exported deployments.
#
# only the CURRENT version of each deployment, analysis and track is exported:
# a row from a submission that a later submission superseded is dropped, using
# the resolved pars_deployments / pars_analyses / pars_tracks as the reference.
#
# writes to output/export/<organization_code>/ by default and returns the paths.
# gpsdata.csv is written only when the organization has mobile deployments.
export_pars_organization <- function (organization_code,
                                      metadata = tar_read(pars_metadata),
                                      detectiondata = tar_read(pars_detectiondata),
                                      gpsdata = tar_read(pars_gpsdata),
                                      deployments = tar_read(pars_deployments),
                                      analyses = tar_read(pars_analyses),
                                      tracks = tar_read(pars_tracks),
                                      dir = file.path("output/export", organization_code)) {
  stopifnot(length(organization_code) == 1, !is.na(organization_code))

  # keep only the current version of each entity
  metadata <- metadata |>
    semi_join(deployments, by = c("submission_id", "deployment_code"))
  detectiondata <- detectiondata |>
    semi_join(analyses, by = c("submission_id", "deployment_code"))
  if (!is.null(gpsdata) && !is.null(tracks)) {
    gpsdata <- gpsdata |>
      semi_join(st_drop_geometry(tracks), by = c("submission_id", "deployment_code"))
  } else {
    gpsdata <- NULL
  }

  # deployment_code identifies one deployment on its own (pars_check_deployment_codes)
  own_deployment_codes <- metadata |>
    filter(deployment_organization_code == organization_code) |>
    pull(deployment_code)

  detectiondata <- detectiondata |>
    filter(
      analysis_organization_code == organization_code |
        deployment_code %in% own_deployment_codes
    )

  metadata <- metadata |>
    filter(
      deployment_organization_code == organization_code |
        deployment_code %in% detectiondata$deployment_code
    )

  if (!is.null(gpsdata)) {
    gpsdata <- gpsdata |>
      filter(deployment_code %in% metadata$deployment_code)
  }

  # back to template shape, keeping submission_id as provenance; datetimes as ISO 8601 strings
  metadata <- metadata |>
    mutate(across(all_of(PARS_METADATA_DATETIMES), format_pars_datetime)) |>
    arrange(deployment_organization_code, deployment_code)
  detectiondata <- detectiondata |>
    mutate(across(all_of(PARS_DETECTIONDATA_DATETIMES), format_pars_datetime)) |>
    arrange(deployment_code, analysis_organization_code, analysis_sound_source_codes, analysis_start_datetime, detection_start_datetime)

  paths <- c(
    metadata = write_export_csv(metadata, dir, "metadata.csv"),
    detectiondata = write_export_csv(detectiondata, dir, "detectiondata.csv")
  )

  if (!is.null(gpsdata) && nrow(gpsdata) > 0) {
    gpsdata <- gpsdata |>
      mutate(across(all_of(PARS_GPSDATA_DATETIMES), format_pars_datetime)) |>
      arrange(deployment_code, datetime)
    paths["gpsdata"] <- write_export_csv(gpsdata, dir, "gpsdata.csv")
  }

  paths
}
