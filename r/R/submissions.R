source("packages.R")

subs_manifest <- read_csv("data-raw/submissions/submissions.csv", show_col_types = FALSE)

# functions --------------------------------------------------------------

# IMPORTANT: changes in source files in `{submission_id}/clean/` are not tracked
# so clean scripts must be re-run manually and then `make_submissions()` must be called to re-load the cleaned data

# re-load all submissions
# make_submissions(subs_manifest$submission_id)
make_submissions <- function (ids = NULL) {
  if (is.null(ids)) {
    tar_invalidate(starts_with("sub_"))
  } else {
    tar_invalidate(any_of(paste0("sub_", ids)))
  }

  tar_make(subs)
}

# run the `clean.R` script for a given submission ID
clean_submission <- function (submission_id, root_dir = "data-raw/submissions") {
  sub_dir <- file.path(root_dir, submission_id)
  clean_script <- file.path(sub_dir, "clean.R")
  stopifnot(file.exists(clean_script))

  source(clean_script, local = new.env(parent = globalenv()))

  clean_dir <- file.path(sub_dir, "clean")
  clean_files <- list.files(clean_dir, pattern = "\\.csv$")
  invisible(clean_files)
}

# clean multiple submissions
# clean_submissions(subs_manifest$submission_id)
clean_submissions <- function (ids) {
  walk(ids, clean_submission)
}

# targets ----------------------------------------------------------------

subs_targets <- tar_map(
  values = list(sub_id = subs_manifest$submission_id, sub_format = subs_manifest$format, sub_skip = subs_manifest$skip),
  names = c(sub_id),
  tar_target(sub, load_submission(sub_id, sub_format, sub_skip, subs_dir, makara_codes), cue = tar_cue(mode = "never"))
)

targets_subs <- list(
  tar_target(subs_dir, "data-raw/submissions"),
  subs_targets,
  tar_combine(
    subs,
    subs_targets,
    command = bind_rows(!!!.x)
  ),

  tar_target(subs_metadata_errors, {
    subs |>
      select(id, metadata) |>
      unnest(metadata) |>
      select(id, errors) |>
      unnest(errors)
  }),
  tar_target(subs_detectiondata_errors, {
    subs |>
      select(id, detectiondata) |>
      unnest(detectiondata) |>
      select(id, errors) |>
      unnest(errors)
  }),
  tar_target(subs_gpsdata_errors, {
    gpsdata <- subs |>
      select(id, gpsdata) |>
      unnest(gpsdata)

    if (nrow(gpsdata) == 0) return(NULL)
    
    gpsdata |>
      select(id, errors) |>
      unnest(errors)
  }),

  tar_target(subs_metadata, {
    x <- subs |>
      select(id, metadata) |>
      unnest(metadata) |> 
      select(submission_id = id, parsed) |> 
      unnest(parsed) |> 
      select(-row)

    stopifnot(
      anyDuplicated(x$UNIQUE_ID) == 0
    )

    x |>
      add_count(UNIQUE_ID) |>
      filter(n > 1) |> 
      tabyl(UNIQUE_ID, submission_id)

    x
  }),
  tar_target(subs_detectiondata, {
    x <- subs |>
      select(id, detectiondata) |>
      unnest(detectiondata) |> 
      select(submission_id = id, parsed) |> 
      unnest(parsed) |> 
      select(-row)

    x |> 
      distinct(submission_id, UNIQUE_ID) |> 
      anti_join(
        subs_metadata, 
        by = c("UNIQUE_ID")
      )
    
    x
  }),
  tar_target(subs_gpsdata, {
    x <- subs |>
      select(id, gpsdata) |>
      unnest(gpsdata) |> 
      select(submission_id = id, parsed) |> 
      unnest(parsed) |> 
      select(-row)

    x_missing <- x |> 
      distinct(submission_id, UNIQUE_ID) |> 
      anti_join(
        subs_metadata, 
        by = c("UNIQUE_ID")
      )
    stopifnot(nrow(x_missing) == 0)
    
    x
  }),

  tar_target(subs_deployments, {
    x <- subs_metadata |> 
      clean_names() |> 
      left_join(
        platform_types |> 
          select(platform_type, deployment_type),
        by = "platform_type"
      ) |>
      transmute(
        submission_id,
        organization_code = case_when(
          submission_id == "ORSTD_20251110_RevWindConstruction2024" ~ "ORSTED",
          submission_id == "ORSTD_20251110_RevWindConstruction2025" ~ "ORSTED",
          str_starts(submission_id, "UCORN_") ~ "CORNELL",
          data_poc_affiliation == "Cornell University" ~ "CORNELL",
          data_poc_affiliation == "DFO Maritimes" ~ "DFO",
          data_poc_affiliation == "NYSDEC" ~ "NYDEC",
          TRUE ~ toupper(data_poc_affiliation)
        ),
        deployment_id = glue("{organization_code}:{unique_id}"),
        deployment_code = unique_id,
        project_id = glue("{organization_code}:{project}"),
        project,
        site = site_id,
        latitude = latitude,
        longitude = longitude,
        monitoring_start_datetime,
        monitoring_end_datetime,
        platform_type,
        deployment_type,
        water_depth_meters,
        recorder_depth_meters = as.character(recorder_depth_meters),
        instrument_type,
        sampling_rate_hz = format_number(sampling_rate_hz),
        data_poc = if_else(is.na(data_poc_name), NA_character_, glue("{data_poc_name} <{data_poc_email}>"))
      )
    
    stopifnot(
      # all(x$organization_code %in% organizations$organization_code),
      anyDuplicated(x$deployment_id) == 0
    )
    
    x
  }),
  tar_target(subs_deployments_map, {
    subs_deployments |> 
      filter(deployment_type == "STATIONARY") |>
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
      mapview::mapview(zcol = "organization_code", layer.name = "deployments")
  }),
  tar_target(subs_deployments_pacm, {
    subs_deployments |> 
      left_join(
        subs_sites |> 
          st_drop_geometry() |> 
          unnest(deployments) |> 
          select(site_id, deployment_id),
        by = "deployment_id"
      ) |> 
      mutate(
        recording_device_lost = FALSE
      ) |> 
      select(all_of(pacm_names$deployments))
  }),

  tar_target(subs_sites, {
    subs_deployments |>
      filter(deployment_type == "STATIONARY") |> 
      select(organization_code, site, deployment_id, latitude, longitude, monitoring_start_datetime, monitoring_end_datetime) |>
      arrange(organization_code, site, monitoring_start_datetime) |>
      nest(versions = -c(organization_code, site)) |>
      mutate(
        versions = map(versions, function (deps) {
          deps_sf <- st_as_sf(deps, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE, sf_column_name = "deployment_geometry")
          n <- nrow(deps_sf)
          geoms <- st_geometry(deps_sf)
          if (n <= 1) {
            deps$dist_to_prev_km <- 0
            deps$site_version <- 1
          } else {
            dist_to_prev_km <- c(0, vapply(seq(2, n, by = 1), function (i) {
              as.numeric(st_distance(geoms[i], geoms[i - 1])) / 1000
            }, numeric(1)))
            deps$dist_to_prev_km <- dist_to_prev_km
            deps$site_version <- cumsum(dist_to_prev_km > 10) + 1
          }
          deps |> 
            nest(deployments = -site_version) |> 
            mutate(
              site_latitude = map_dbl(deployments, ~ first(.$latitude)),
              site_longitude = map_dbl(deployments, ~ first(.$longitude)),
              n_deployments = map_int(deployments, nrow)
            )
        })
      ) |> 
      unnest(versions) |> 
      group_by(site) |> 
      mutate(
        n_versions = max(site_version),
        site_id = if_else(
          n_versions > 1,
          glue("{organization_code}:{site}:{site_version}"),
          glue("{organization_code}:{site}")
        )
      ) |> 
      relocate(site_id, .before = site) |>
      ungroup() |> 
      select(-n_versions)
  }),
  tar_target(subs_sites_map, {
    subs_sites |> 
      select(-deployments) |> 
      st_as_sf(coords = c("site_longitude", "site_latitude"), crs = 4326) |>
      mapview::mapview(label = "site_id", zcol = "n_deployments", layer.name = "# deployments")
  }),
  tar_target(subs_sites_pacm, {
    subs_sites |> 
      select(all_of(pacm_names$sites))
  }),

  tar_target(subs_analyses, {
    x <- subs_detectiondata |> 
      janitor::clean_names() |> 
      rename(
        qc_data = qc_processing,
        species = species_code,
        call_type = call_type_code
      ) |> 
      nest(detections = -c(
        submission_id, 
        unique_id,
        detection_method,
        protocol_reference,
        detection_software_name,
        detection_software_version,
        qc_data,
        species,
        # min_analysis_frequency_range_hz,
        # max_analysis_frequency_range_hz,
        # analysis_sampling_rate_hz,
        # call_type
      )) |> 
      mutate(
        min_analysis_frequency_range_hz = map_dbl(detections, ~ min(as.numeric(.$min_analysis_frequency_range_hz), na.rm = TRUE)),
        max_analysis_frequency_range_hz = map_dbl(detections, ~ max(as.numeric(.$max_analysis_frequency_range_hz), na.rm = TRUE)),
        analysis_sampling_rate_hz = map_dbl(detections, ~ max(as.numeric(.$analysis_sampling_rate_hz), na.rm = TRUE)),
        call_type = map_chr(detections, ~ str_c(na.omit(unique(.$call_type)), collapse = ","))
      ) |>
      left_join(
        subs_deployments |> 
          select(
            organization_code, deployment_id, deployment_code,
            recorder_depth_meters, instrument_type, sampling_rate_hz, water_depth_meters,
            platform_type, deployment_type, site
          ),
        by = c("unique_id" = "deployment_code")
      ) |> 
      mutate(
        organization_code,
        deployment_code = unique_id,
        analysis_id = glue("{deployment_id}:{species}"),
        analysis_sampling_rate_hz = as.numeric(analysis_sampling_rate_hz),
        detections = map(detections, function (detections) {
          detections |>
            mutate(date = as_date(analysis_period_start_datetime)) |> 
            nest(detections = -c(date)) |> 
            mutate(
              n_detected = map_int(detections, ~ sum(.$acoustic_presence == "DETECTED")),
              n_not_detected = map_int(detections, ~ sum(.$acoustic_presence == "NOT_DETECTED")),
              n_possibly_detected = map_int(detections, ~ sum(.$acoustic_presence == "POSSIBLY_DETECTED")),
              n_not_available = map_int(detections, ~ sum(.$acoustic_presence == "NOT_AVAILABLE")),
              presence = case_when(
                n_detected > 0 ~ "y",
                n_possibly_detected > 0 ~ "m",
                n_not_detected > 0 ~ "n",
                TRUE ~ "na"
              ),
              locations = list(NULL)
            )
        }),
        n_detections = map_int(detections, nrow),
        analysis_period = map(detections, function (detections) {
          list(
            analysis_start_date = min(detections$date),
            analysis_end_date = max(detections$date)
          )
        })
      ) |> 
      unnest_wider(analysis_period)
    
    tabyl(x, species)
    tabyl(x, detection_method)

    x
  }),
  tar_target(subs_analyses_pacm, {
    subs_analyses |> 
      mutate(
        detections = map(detections, function (detections) {
          select(detections, all_of(pacm_names$analyses_detections))
        })
      ) |> 
      select(all_of(pacm_names$analyses))
  }),

  tar_target(subs_tracks, {
    track_positions <- subs_gpsdata |>
      clean_names() |> 
      select(-submission_id) |> 
      rename(deployment_code = unique_id) |> 
      arrange(deployment_code, datetime)

    # aggregate to hourly positions (first position in each hour)
    track_positions_hourly <- track_positions |> 
      mutate(
        datetime_hour = floor_date(datetime, unit = "hour")
      ) |> 
      group_by(deployment_code, datetime_hour) |> 
      slice_min(order_by = datetime, n = 1) |> 
      ungroup() |> 
      select(-datetime_hour)
    
    # convert to sf linestrings
    track_positions_hourly_sf <- track_positions_hourly |> 
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |> 
      arrange(deployment_code, datetime) |> 
      group_by(deployment_code) |> 
      summarise(
        start_datetime = min(datetime),
        end_datetime = max(datetime),
        start_latitude = first(latitude),
        start_longitude = first(longitude),
        end_latitude = last(latitude),
        end_longitude = last(longitude),
        do_union = FALSE
      ) |> 
      st_cast("LINESTRING") |> 
      ungroup()

    # mapview::mapview(track_positions_hourly_sf, legend = FALSE)

    tracks <- track_positions_hourly_sf |> 
      left_join(
        subs_deployments |> 
          select(organization_code, deployment_id, deployment_code),
        by = c("deployment_code")
      ) |> 
      mutate(track_id = glue("{deployment_id}:TRACK")) |> 
      st_cast("MULTILINESTRING")

    stopifnot(
      all(!duplicated(tracks$track_id)),
      all(!duplicated(tracks$deployment_id))
    )
    
    tracks
  }),
  tar_target(subs_tracks_pacm, {
    subs_tracks |> 
      select(all_of(pacm_names$tracks))
  }),

  tar_target(subs_pacm, {
    stopifnot(
      nrow(subs_metadata_errors) == 0,
      nrow(subs_detectiondata_errors) == 0,
      nrow(subs_gpsdata_errors) == 0,
      all(!is.na(subs_deployments_pacm$organization_code)),
      all(na.omit(subs_deployments_pacm$site_id) %in% subs_sites_pacm$site_id),
      all(subs_analyses_pacm$deployment_id %in% subs_deployments_pacm$deployment_id),
      all(subs_tracks_pacm$deployment_id %in% subs_deployments_pacm$deployment_id),
      !anyDuplicated(subs_sites_pacm$site_id),
      !anyDuplicated(subs_deployments_pacm$deployment_id),
      !anyDuplicated(subs_analyses_pacm$analysis_id),
      !anyDuplicated(subs_tracks_pacm$track_id)
    )
    list(
      sites = subs_sites_pacm,
      deployments = subs_deployments_pacm,
      analyses = subs_analyses_pacm,
      tracks = subs_tracks_pacm
    )
  })
)
