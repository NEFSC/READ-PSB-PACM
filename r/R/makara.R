makara_connect <- function () {
  con <- DBI::dbConnect(
    RPostgres::Postgres(),
    host = Sys.getenv("MAKARA_HOST"),
    port = Sys.getenv("MAKARA_PORT"),
    dbname = Sys.getenv("MAKARA_DBNAME"),
    user = Sys.getenv("MAKARA_USER"),
    password = Sys.getenv("MAKARA_PASSWORD")
  )
}

targets_makara <- list(
  tar_target(makara_exclude_organizations, c("DFO", "JASCO", "CORNELL", "ORSTED")),
  tar_target(makara_db, {
    con <- makara_connect()

    platform_types <- tbl(con, "platform_types") |> 
      collect()
    sound_sources <- tbl(con, "sound_sources") |> 
      collect()
    call_types <- tbl(con, "call_types") |> 
      collect()
    reference_codes <- tbl(con, "reference_codes") |> 
      collect()
    
    organizations <- tbl(con, "organizations") |>
      collect()
    deployments <- tbl(con, "deployments") |>
      collect()
    deployments_devices <- tbl(con, "deployments_devices") |>
      collect()
    projects <- tbl(con, "projects") |>
      collect()
    sites <- tbl(con, "sites") |>
      collect()
    devices <- tbl(con, "devices") |>
      collect()
    recordings <- tbl(con, "recordings") |>
      collect()
    recordings_devices <- tbl(con, "recordings_devices") |>
      collect()
    analyses <- tbl(con, "analyses") |>
      collect()
    analyses_recordings <- tbl(con, "analyses_recordings") |>
      collect()
    analyses_detectors <- tbl(con, "analyses_detectors") |>
      collect()
    analyses_sound_sources <- tbl(con, "analyses_sound_sources") |>
      collect()
    detectors <- tbl(con, "detectors") |>
      collect()
    analyses_n_detections <- tbl(con, "detections") |> 
      count(analysis_id) |> 
      collect()
    detections_daily <- tbl(con, "daily_presence_detections") |> 
      collect()
    detections_mobile <- tbl(con, "detections") |> 
      left_join(
        tbl(con, "analyses") |> 
          select(analysis_id = id, deployment_id),
        by = "analysis_id"
      ) |> 
      left_join(
        tbl(con, "deployments") |> 
          select(deployment_id = id, platform_type_code) |> 
          left_join(
            tbl(con, "platform_types") |> 
              select(platform_type_code = code, platform_type_mobile = mobile),
            by = c("platform_type_code")
          ),
        by = c("deployment_id")
      ) |> 
      filter(
        platform_type_mobile,
        detection_result_code %in% c("DETECTED", "POSSIBLY_DETECTED")
      ) |> 
      collect()
    track_positions <- tbl(con, "track_positions") |> 
      collect()
    tracks <- tbl(con, "tracks") |> 
      collect()

    DBI::dbDisconnect(con)
    list(
      organizations = organizations,
      deployments = deployments,
      deployments_devices = deployments_devices,
      projects = projects,
      sites = sites,
      devices = devices,
      recordings = recordings,
      recordings_devices = recordings_devices,
      analyses = analyses,
      analyses_n_detections = analyses_n_detections,
      analyses_recordings = analyses_recordings,
      analyses_detectors = analyses_detectors,
      analyses_sound_sources = analyses_sound_sources,
      detectors = detectors,
      detections_daily = detections_daily,
      detections_mobile = detections_mobile,
      track_positions = track_positions,
      tracks = tracks,

      sound_sources = sound_sources,
      call_types = call_types,
      platform_types = platform_types,
      reference_codes = reference_codes
    )
  }),

  tar_target(makara_codes, {
    makara_db$reference_codes |> 
      group_by(table) |> 
      summarise(code = list(unique(code))) |> 
      deframe()
  }),

  tar_target(makara_jasco, {
    # extract older JASCO deployments that were analyzed by NEFSC (all other JASCO data will be dropped and included in submissions instead)
    analyses <- makara_db$analyses |> 
      left_join(
        makara_db$deployments |> 
          select(deployment_id = id, deployment_organization_code = organization_code),
        by = c("deployment_id")
      ) |>
      filter(
        analysis_organization_code == "NEFSC",
        deployment_organization_code == "JASCO"
      ) |> 
      select(-deployment_organization_code)
    
    recordings <- makara_db$recordings |> 
      semi_join(
        makara_db$analyses_recordings |> 
          semi_join(analyses, by = c("analysis_id" = "id")),
        by = c("id" = "recording_id")
      )
    
    deployments <- makara_db$deployments |> 
      semi_join(
        makara_db$analyses |> 
          semi_join(analyses, by = c("deployment_id" = "deployment_id")),
        by = c("id" = "deployment_id")
      )
    
    sites <- makara_db$sites |> 
      semi_join(
        deployments,
        by = c("id" = "site_id")
      )
    
    projects <- makara_db$projects |> 
      semi_join(
        deployments,
        by = c("id" = "project_id")
      )
    
    recording_device_ids <- makara_db$devices |> 
      semi_join(
        makara_db$recordings_devices |> 
          semi_join(recordings, by = c("recording_id" = "id")),
        by = c("id" = "device_id")
      ) |> 
      pull(id)
    deployment_device_ids <- makara_db$devices |> 
      semi_join(
        makara_db$deployments_devices |> 
          semi_join(deployments, by = c("deployment_id" = "id")),
        by = c("id" = "device_id")
      ) |> 
      pull(id)
    devices <- makara_db$devices |> 
      filter(id %in% union(recording_device_ids, deployment_device_ids))

    list(
      sites = sites,
      projects = projects,
      deployments = deployments,
      devices = devices,
      recordings = recordings,
      analyses = analyses
    )
  }),
  tar_target(makara_sites, {
    x <- makara_db$sites |> 
      filter(!organization_code %in% makara_exclude_organizations) |> 
      bind_rows(makara_jasco$sites) |>
      transmute(
        organization_code,
        makara_site_id = id,
        site_id = glue("{organization_code}:{site_code}"),
        site = site_code,
        site_latitude,
        site_longitude
      ) |>
      inner_join(
        makara_db$deployments |>
          select(
            makara_site_id = site_id,
            makara_deployment_id = id, organization_code, deployment_code,
            deployment_latitude, deployment_longitude,
            deployment_datetime
          ) |> 
          arrange(makara_site_id, deployment_datetime) |>
          nest(deployments = -makara_site_id),
        by = "makara_site_id"
      )
    
    x1 <- x |> 
      filter(!is.na(site_latitude), !is.na(site_longitude))
    
    x2 <- x |> 
      filter(is.na(site_latitude), is.na(site_longitude)) |> 
      select(-site_latitude, -site_longitude) |>
      mutate(
        versions = map(deployments, function (deps) {
          deps_sf <- st_as_sf(deps, coords = c("deployment_longitude", "deployment_latitude"), crs = 4326, remove = FALSE, sf_column_name = "deployment_geometry")
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
              site_latitude = map_dbl(deployments, ~ first(.$deployment_latitude)),
              site_longitude = map_dbl(deployments, ~ first(.$deployment_longitude)),
              n_deployments = map_int(deployments, nrow)
            )
        })
      ) |> 
      select(-deployments) |> 
      unnest(versions) |> 
      group_by(site_id) |> 
      mutate(
        n_versions = max(site_version),
        site_id = if_else(
          n_versions > 1,
          glue("{site_id}:{site_version}"),
          glue("{site_id}")
        )
      ) |>
      ungroup() |> 
      select(-n_versions, -n_deployments, -site_version) |> 
      relocate(deployments, .after = last_col())

    bind_rows(
      x1,
      x2
    )
  }),
  tar_target(makara_projects, {
    makara_db$projects |> 
      filter(!organization_code %in% makara_exclude_organizations) |> 
      bind_rows(makara_jasco$projects) |>
      transmute(
        makara_project_id = id,
        project_id = glue("{organization_code}:{project_code}"),
        project_code,
        project_name,
        project_contacts,
        project_funding
      )
  }),
  tar_target(makara_deployments, {
    deployment_recordings <- makara_recordings |> 
      select(-deployment_id) |> 
      rename(deployment_id = makara_deployment_id) |>
      nest(.by = deployment_id, .key = "recordings") |> 
      mutate(
        recording_end_datetime = map_chr(recordings, function (x) {
          if (all(is.na(x$recording_end_datetime))) return(NA_character_)
          format_ISO8601(max(x$recording_end_datetime, na.rm = TRUE))
        }),
        recording_end_datetime = ymd_hms(recording_end_datetime)
      )
    
    makara_db$deployments |> 
      filter(!organization_code %in% makara_exclude_organizations) |> 
      bind_rows(makara_jasco$deployments) |>
      rename(
        makara_deployment_id = id,
        makara_site_id = site_id,
        makara_project_id = project_id
      ) |> 
      left_join(
        makara_db$platform_types |> 
          select(
            platform_type_code = code,
            platform_type_mobile = mobile
          ),
        by = c("platform_type_code")
      ) |> 
      left_join(
        makara_sites |> 
          select(deployments, site_id, site) |> 
          unnest(deployments) |>
          select(makara_deployment_id, site_id, site),
        by = c("makara_deployment_id")
      ) |> 
      left_join(
        makara_projects |> 
          select(
            makara_project_id,
            project_id,
            project_code,
            project_contacts
          ),
        by = c("makara_project_id")
      ) |> 
      left_join(
        deployment_recordings,
        by = c("makara_deployment_id" = "deployment_id")
      ) |> 
      transmute(
        makara_deployment_id,
        deployment_id = glue("{organization_code}:{deployment_code}"),
        organization_code,
        deployment_code,
        site_id,
        project_id,
        recordings,

        # project
        project = project_code,
        data_poc = project_contacts,

        # deployment
        site,
        latitude = deployment_latitude,
        longitude = deployment_longitude,
        monitoring_start_datetime = deployment_datetime,
        monitoring_end_datetime = coalesce(recovery_datetime, recording_end_datetime),
        platform_type = platform_type_code,
        deployment_type = if_else(platform_type_mobile, "MOBILE", "STATIONARY"),
        water_depth_meters = deployment_water_depth_m,

        # recording
        recorder_depth_meters = map_chr(recordings, ~ format_range(.x$recorder_depth_meters)),
        instrument_type = map_chr(recordings, ~ format_list(unlist(.x$device_type_codes))),
        sampling_rate_hz = map_chr(recordings, ~ format_range(.x$sampling_rate_hz)),
        recording_device_lost = map_lgl(recordings, ~ any(.x$recording_device_lost))
      )
  }),
  tar_target(makara_recordings, {
    device_type_codes <- makara_db$recordings |> 
      filter(!organization_code %in% makara_exclude_organizations) |> 
      bind_rows(makara_jasco$recordings) |>
      select(recording_id = id) |> 
      left_join(
        makara_db$recordings_devices,
        by = c("recording_id")
      ) |> 
      left_join(
        makara_db$devices |> 
          select(
            device_id = id,
            device_type_code
          ),
        by = c("device_id")
      ) |> 
      group_by(recording_id) |> 
      summarise(
        device_type_codes = list(device_type_code)
      )
    
    device_type_codes |> 
      unnest_longer(device_type_codes) |>
      tabyl(device_type_codes)

    makara_db$recordings |>
      left_join(
        makara_db$deployments |> 
          select(deployment_id = id, deployment_code),
        by = c("deployment_id")
      ) |> 
      left_join(
        device_type_codes,
        by = c("id" = "recording_id")
      ) |> 
      transmute(
        makara_deployment_id = deployment_id,
        makara_recording_id = id,
        deployment_id = glue("{deployment_code}:{recording_code}"),
        recording_id = glue("{deployment_id}:{recording_code}"),
        recording_code,
        device_type_codes,
        recording_start_datetime,
        recording_end_datetime,
        recorder_depth_meters = recording_device_depth_m,
        sampling_rate_hz = recording_sample_rate_khz * 1000,
        recording_quality_type_code,
        recording_device_lost = coalesce(recording_quality_type_code == "UNUSABLE", recording_device_lost, FALSE)
      )
  }),
  tar_target(makara_analyses, {
    analyses_recordings <- makara_db$analyses |> 
      select(analysis_id = id) |> 
      left_join(
        makara_db$analyses_recordings |> 
          select(-id),
        by = c("analysis_id")
      ) |> 
      left_join(
        makara_recordings,
        by = c("recording_id" = "makara_recording_id")
      ) |> 
      nest(.by = analysis_id, .key = "recordings")

    # analyses with multiple recordings
    analyses_recordings |> 
      mutate(n_recordings = map_int(recordings, nrow)) |> 
      filter(n_recordings > 1) |> 
      unnest(recordings)
    
    analyses_detectors <- makara_db$analyses |> 
      select(analysis_id = id) |> 
      left_join(
        makara_db$analyses_detectors |> 
          select(analysis_id, detector_code = detector_id),
        by = c("analysis_id")
      ) |> 
      group_by(analysis_id) |>
      summarise(
        detector_codes = list(detector_code)
      )

    # analyses with multiple detectors
    analyses_detectors |> 
      mutate(n_detectors = map_int(detector_codes, length)) |> 
      filter(n_detectors > 1) |> 
      unnest_longer(detector_codes) |> 
      tabyl(detector_codes)

    analyses_sound_sources <- makara_db$analyses_sound_sources |> 
      select(analysis_id, sound_source_code = soundsource_id) |> 
      group_by(analysis_id) |>
      summarise(
        sound_source_codes = list(sound_source_code)
      )
    
    # analyses with multiple sound sources
    analyses_sound_sources |> 
      mutate(n_sound_sources = map_int(sound_source_codes, length)) |> 
      filter(n_sound_sources > 1)

    makara_db$analyses |> 
      semi_join(makara_deployments, by = c("deployment_id" = "makara_deployment_id")) |>
      semi_join(
        makara_db$analyses_n_detections |> 
          filter(n > 0),
        by = c("id" = "analysis_id")
      ) |> 
      left_join(
        makara_db$deployments |> 
          select(deployment_id = id, deployment_code, deployment_organization_code = organization_code),
        by = c("deployment_id")
      ) |> 
      left_join(
        analyses_recordings,
        by = c("id" = "analysis_id")
      ) |> 
      left_join(
        analyses_detectors,
        by = c("id" = "analysis_id")
      ) |> 
      left_join(
        analyses_sound_sources,
        by = c("id" = "analysis_id")
      ) |> 
      transmute(
        makara_deployment_id = deployment_id,
        makara_analysis_id = id,
        analysis_organization_code,
        deployment_id = glue("{deployment_organization_code}:{deployment_code}"),
        analysis_id = glue("{deployment_id}:{analysis_organization_code}:{analysis_code}"),
        analysis_code,
        recordings,
        detector_codes,
        sound_source_codes,

        recorder_depth_meters = map_chr(recordings, ~ format_range(.x$recorder_depth_meters)),
        instrument_type = map_chr(recordings, ~ format_list(unlist(.x$device_type_codes))),
        sampling_rate_hz = map_chr(recordings, ~ format_range(.x$sampling_rate_hz)),
        detection_method = map_chr(detector_codes, ~ paste(unique(.x), collapse = ",")),

        analyzed = TRUE,
        call_type = NA_character_,
        qc_data = analysis_processing_code,
        analysis_sampling_rate_hz = analysis_sample_rate_khz * 1000,
        protocol_reference = analysis_protocol_reference,
        analysis_start_date = as_date(analysis_start_datetime),
        analysis_end_date = as_date(analysis_end_datetime)
      )
  }),
  tar_target(makara_track_positions, {
    makara_db$track_positions |>
      select(
        track_id,
        datetime = track_position_datetime,
        latitude = track_position_latitude,
        longitude = track_position_longitude
      )
  }),
  tar_target(makara_tracks, {
    # aggregate to hourly positions (first position in each hour)
    track_positions_hourly <- makara_track_positions |> 
      mutate(
        datetime_hour = floor_date(datetime, unit = "hour")
      ) |> 
      group_by(track_id, datetime_hour) |> 
      slice_min(order_by = datetime, n = 1) |> 
      ungroup() |> 
      select(-datetime_hour)
    
    # convert to sf linestrings
    track_positions_hourly_sf <- track_positions_hourly |> 
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |> 
      arrange(track_id, datetime) |> 
      group_by(track_id) |> 
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

    tracks_sf <- makara_db$tracks |> 
      filter(!organization_code %in% makara_exclude_organizations) |> 
      select(organization_code, deployment_id, track_id = id, track_code) |> 
      inner_join(
        track_positions_hourly_sf,
        by = c("track_id")
      ) |> 
      st_as_sf() |>
      st_cast("MULTILINESTRING") |> 
      relocate(organization_code, deployment_id, track_id, track_code)

    stopifnot(
      all(!duplicated(tracks_sf$track_id)),
      all(!duplicated(tracks_sf$deployment_id))
    )
    
    tracks_sf |> 
      rename(
        makara_deployment_id = deployment_id,
        makara_track_id = track_id
      ) |> 
      left_join(
        makara_deployments |> 
          select(makara_deployment_id, deployment_id),
        by = "makara_deployment_id"
      ) |> 
      mutate(
        track_id = glue("{deployment_id}:{track_code}")
      ) |> 
      relocate(deployment_id, track_id, .after = makara_track_id)
  }),

  tar_target(makara_detections_daily, {
    makara_db$detections_daily |> 
      transmute(
        analysis_id,
        date,
        species = sound_source_code,
        presence = case_when(
          n_detected > 0 ~ "y",
          n_possibly_detected > 0 ~ "m",
          n_not_detected > 0 ~ "n",
          TRUE ~ "na"
        )
      )
  }),
  tar_target(makara_detections_mobile, {
    x <- makara_db$detections_mobile |>
      transmute(
        analysis_id,
        date = as_date(detection_start_datetime),
        species = sound_source_code,
        
        analysis_period_start_datetime = detection_start_datetime,
        analysis_period_end_datetime = detection_end_datetime,
        analysis_period_effort_seconds = detection_effort_secs,
        latitude = detection_latitude,
        longitude = detection_longitude,
        presence = case_when(
          detection_result_code == "DETECTED" ~ "y",
          detection_result_code == "POSSIBLY_DETECTED" ~ "m",
          detection_result_code == "NOT_DETECTED" ~ "n",
          TRUE ~ "na"
        )
      )
    
    # fill missing lat/lon from tracks (for mobile deployments with missing track data, these will be filled with NA and handled in the PACM submission)
    x_missing_coord <- x |> 
      filter(is.na(latitude) | is.na(longitude)) |> 
      select(makara_analysis_id = analysis_id, analysis_period_start_datetime) |> 
      left_join(
        makara_analyses |> 
          select(makara_analysis_id, makara_deployment_id),
        by = c("makara_analysis_id")
      ) |> 
      nest(datetimes = analysis_period_start_datetime)

    x_missing_coord_tracks <- makara_track_positions |> 
      rename(makara_track_id = track_id) |> 
      left_join(
        makara_db$tracks |> 
          select(makara_deployment_id = deployment_id, makara_track_id = id),
        by = c("makara_track_id")
      ) |> 
      filter(!is.na(datetime), !is.na(latitude), !is.na(longitude)) |>
      distinct() |> 
      arrange(makara_deployment_id, datetime) |>
      slice_head(n = 1, by = c(makara_deployment_id, datetime)) |>
      nest(track = c(datetime, latitude, longitude)) |> 
      mutate(
        interp = map(track, function (track) {
          lat <- approxfun(track$datetime, y = track$latitude, rule = 2)
          lon <- approxfun(track$datetime, y = track$longitude, rule = 2)
          list(lat = lat, lon = lon)
        })
      ) |> 
      select(makara_deployment_id, interp)

    x_missing_coord_interp <- x_missing_coord |> 
      inner_join(x_missing_coord_tracks, by = "makara_deployment_id") |> 
      mutate(
        data = map2(datetimes, interp, function (x, interp) {
          tibble(
            analysis_period_start_datetime = x$analysis_period_start_datetime,
            track_latitude = interp[["lat"]](x$analysis_period_start_datetime),
            track_longitude = interp[["lon"]](x$analysis_period_start_datetime)
          )
        })
      )
    
    x_filled <- x |> 
      left_join(
        x_missing_coord_interp |> 
          select(makara_analysis_id, data) |> 
          unnest(data),
        by = c("analysis_id" = "makara_analysis_id", "analysis_period_start_datetime"),
        relationship = "many-to-many"
      ) |> 
      mutate(
        track_filled = is.na(latitude) & !is.na(track_latitude) & is.na(longitude) & !is.na(track_longitude),
        latitude = coalesce(latitude, track_latitude),
        longitude = coalesce(longitude, track_longitude)
      )
    
    # remaining missing lat/lon
    x_filled |> 
      filter(is.na(latitude) | is.na(longitude)) |> 
      left_join(
        makara_analyses |> 
          select(makara_analysis_id, makara_deployment_id, deployment_id),
        by = c("analysis_id" = "makara_analysis_id")
      ) |>
      tabyl(makara_deployment_id)

    x_filled |> 
      select(-track_latitude, -track_longitude, -track_filled) |>
      nest(.by = c("analysis_id", "date", "species"), .key = "locations")
  }),
  tar_target(makara_detections, {
    makara_detections_daily |> 
      left_join(
        makara_detections_mobile |> 
          select(analysis_id, date, species, locations),
        by = c("analysis_id", "date", "species")
      ) |> 
      mutate(
        n_locations = map_int(locations, function (x) {
          if (is.null(x)) return(0L)
          nrow(x)
        })
      ) |> 
      rename(makara_analysis_id = analysis_id) |> 
      inner_join(
        makara_analyses |> 
          select(makara_analysis_id, analysis_id),
        by = "makara_analysis_id"
      ) |> 
      relocate(analysis_id, .after = "makara_analysis_id")
  }),

  tar_target(makara_mobile_deployments_missing_tracks, {
    # TODO: mobile deployments with missing track data (from data migration)
    x <- setdiff(
      makara_deployments |> 
        filter(deployment_type == "MOBILE") |> 
        pull(deployment_id),
      makara_tracks$deployment_id
    ) |> 
      sort()
    if (length(x) > 0) {
      warning(glue("[makara] Found {length(x)} mobile deployments missing tracks"))
    }
    x
  }),

  tar_target(makara_sites_pacm, {
    makara_sites |> 
      select(all_of(pacm_names$sites))
  }),
  tar_target(makara_deployments_pacm, {
    makara_deployments |> 
      select(-recordings, -site_id, -project_id) |> 
      left_join(
        makara_sites |>  
          select(site_id, site, deployments) |> 
          unnest(deployments) |> 
          select(site_id, makara_deployment_id),
        by = "makara_deployment_id"
      ) |> 
      select(all_of(pacm_names$deployments))
  }),

  tar_target(makara_tracks_pacm, {
    makara_tracks |> 
      select(all_of(pacm_names$tracks))
  }),

  tar_target(makara_analyses_pacm_realtime_file, "data-raw/realtime/realtime-analyses.rds", format = "file"),
  tar_target(makara_analyses_pacm_realtime, {
    read_rds(makara_analyses_pacm_realtime_file) |> 
      mutate(
        detections = map(detections, function (detections) {
          if (is.null(detections)) return(NULL)
          detections |> 
            mutate(
              locations = map(locations, function (locations) {
                if (is.null(locations)) return(NULL)
                locations |> 
                  filter(!is.na(latitude) & !is.na(longitude))
              })
            )
        })
      )
  }),
  tar_target(makara_analyses_pacm, {
    x <- makara_analyses |> 
      select(
        organization_code = analysis_organization_code,
        deployment_id,
        analysis_id,
        recorder_depth_meters,
        instrument_type,
        sampling_rate_hz,
        detection_method,
        analyzed,
        call_type,
        qc_data,
        analysis_sampling_rate_hz,
        protocol_reference,
        analysis_start_date,
        analysis_end_date,
        species = sound_source_codes
      ) |> 
      unnest_longer(species) |> 
      left_join(
        makara_detections |>
          select(analysis_id, date, species, presence, locations) |> 
          nest(detections = -c(analysis_id, species)) |> 
          mutate(
            detections = map(detections, function (detections) {
              detections |> 
                select(all_of(pacm_names$analyses_detections))
            })
          ),
        by = c("analysis_id", "species")
      ) |> 
      mutate(
        n_detections = map_int(detections, function (detections) {
          if (is.null(detections)) return(0L)
          nrow(detections)
        })
      )
    
    # TODO: find missing detection data
    x_no_detections <- x |> 
      filter(n_detections == 0)
    
    x |> 
      select(all_of(pacm_names$analyses)) |> 
      bind_rows(makara_analyses_pacm_realtime)
  }),

  tar_target(makara_pacm, {
    stopifnot(
      all(na.omit(makara_deployments_pacm$site_id) %in% makara_sites_pacm$site_id),
      all(makara_analyses_pacm$deployment_id %in% makara_deployments_pacm$deployment_id),
      all(makara_tracks_pacm$deployment_id %in% makara_deployments_pacm$deployment_id)
    )
    list(
      sites = makara_sites_pacm,
      deployments = makara_deployments_pacm,
      analyses = makara_analyses_pacm,
      tracks = makara_tracks_pacm
    )
  })
)
