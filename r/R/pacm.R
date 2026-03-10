create_theme <- function (data, species) {
  analyses <- data$analyses |> 
    filter(species %in% !!species) |>
    left_join(
      bind_rows(data$deployments) |> 
        select(
          deployment_id,
          deployment_code,
          project,
          site_id,
          site,
          latitude,
          longitude,
          monitoring_start_datetime,
          monitoring_end_datetime,
          platform_type,
          deployment_type,
          water_depth_meters,
          data_poc
        ),
      by = "deployment_id"
    ) |> 
    transmute(
      id = deployment_id,
      analysis_id,
      site_id,
      organization_code,

      data_poc,

      deployment_id,
      deployment_code,
      project,
      site,
      latitude,
      longitude,
      monitoring_start_datetime,
      monitoring_end_datetime,
      platform_type,
      deployment_type,
      water_depth_meters,
      
      recorder_depth_meters,
      instrument_type,
      sampling_rate_hz,
      detection_method,
      
      # TODO: excluding these for now, CVOWC used different freq/call type within BLWH causing duplicate IDs
      call_type = NA_character_,
      analysis_sampling_rate_hz = NA_real_,
      qc_data,
      protocol_reference,
      analysis_start_date,
      analysis_end_date,

      species,
      detections
    ) |> 
    nest(detections = c(species, detections))

  stopifnot(
    all(!is.na(analyses$analysis_id)),
    all(!duplicated(analyses$analysis_id))
  )

  tracks <- data$tracks |> 
    filter(deployment_id %in% analyses$deployment_id) |> 
    mutate(id = deployment_id)

  detections <- analyses |>
    select(id, analysis_id, deployment_id, detections) |> 
    unnest(detections) |> 
    unnest(detections)

  deployments <- analyses |> 
    select(-detections)

  sites <- data$sites |> 
    filter(site_id %in% deployments$site_id)

  list(
    sites = sites,
    deployments = deployments,
    detections = detections,
    tracks = tracks
  )
}

targets_pacm <- list(
  tar_target(pacm_dir, "data/pacm"),

  tar_target(pacm_names, {
    list(
      sites = c(
        "organization_code",
        "site_id",
        "site",
        "site_latitude",
        "site_longitude"
      ),
      deployments = c(
        "organization_code",
        "deployment_id",
        "deployment_code",
        "project",
        "site_id",
        "site",
        "latitude",
        "longitude",
        "monitoring_start_datetime",
        "monitoring_end_datetime",
        "platform_type",
        "deployment_type",
        "water_depth_meters",
        "recorder_depth_meters",
        "instrument_type",
        "sampling_rate_hz",
        "data_poc"
      ),
      analyses = c(
        "organization_code",
        "analysis_id",
        "deployment_id",

        "recorder_depth_meters",
        "instrument_type",
        "sampling_rate_hz",

        "detection_method",
        "call_type",
        "qc_data",
        "analysis_sampling_rate_hz",
        "protocol_reference",
        "analysis_start_date",
        "analysis_end_date",
        "species",
        "detections"
      ),
      analyses_detections = c(
        "date",
        "presence",
        "locations"
      ),
      tracks = c(
        "organization_code",
        "deployment_id",
        "track_id"
      )
    )
  }),

  tar_target(pacm_data_raw, {
    bind_rows(
      makara = enframe(makara_pacm),
      towed = enframe(towed_pacm),
      submissions = enframe(subs_pacm),
      .id = "dataset"
    ) |> 
      pivot_wider()
  }),

  tar_target(pacm_exclude, {
    tracks <- bind_rows(pacm_data_raw$tracks)

    deployments_mobile <- bind_rows(pacm_data_raw$deployments) |> 
      filter(deployment_type == "MOBILE")

    # mobile deployments with missing tracks
    deployments_mobile_missing_tracks <- deployments_mobile |> 
      anti_join(tracks, by = c("deployment_id"))

    stopifnot(
      # no analyses so ok to drop
      bind_rows(pacm_data_raw$analyses) |> 
        filter(deployment_id %in% deployments_mobile_missing_tracks$deployment_id) |> 
        nrow() == 0
    )

    list(
      deployments = deployments_mobile_missing_tracks$deployment_id
    )
  }),

  tar_target(pacm_data, {
    deployments <- bind_rows(pacm_data_raw$deployments) |> 
      filter(!deployment_id %in% pacm_exclude$deployments)
    sites <- bind_rows(pacm_data_raw$sites) |> 
      filter(site_id %in% deployments$site_id)
    tracks <- bind_rows(pacm_data_raw$tracks) |> 
      filter(deployment_id %in% deployments$deployment_id)
    
    analyses_data <- bind_rows(pacm_data_raw$analyses) |> 
      filter(deployment_id %in% deployments$deployment_id) |>
      mutate(
        detection_method = iconv(detection_method, "UTF-8", "UTF-8", sub = ""),
        detection_method = toupper(detection_method),
        detection_method = case_when(
          str_detect(detection_method, "JASCO") ~ "JASCO",
          detection_method == "AUTOMATIC AND MANUAL" ~ "AUTOMATIC/MANUAL",
          detection_method == "CUSTOM AUTOMATIC DETECTOR" ~ "AUTOMATIC",
          str_starts(detection_method, "PAMGUARD WHISTLE") ~ "PAMGUARD",
          detection_method == "PAMLAB, MANUAL" ~ "PAMLAB/MANUAL",
          detection_method == "PAMGUARD,MANUAL" ~ "PAMGUARD/MANUAL",
          str_detect(detection_method, "RPS CONTOUR AND CLICK DETECTORS") ~ "RPS",
          str_detect(detection_method, "MATLAB-BASED AUTOMATED DETECTOR ALGORITHM") ~ "MATLAB",
          str_detect(detection_method, "MATCHED-FILTER DATA-TEMPLATE DETECTION ALGORITHM") ~ "MATCHED_FILTER",
          TRUE ~ detection_method
        ),
        detections = map(detections, function (x) {
          if (is.null(x)) {
            return(NULL)
          }
          x |> 
            mutate(
              locations = map(locations, function (locs) {
                if (is.null(locs)) {
                  return(NULL)
                }
                locs |> 
                  mutate(date = as_date(analysis_period_start_datetime)) |>
                  slice_head(n = 1, by = date) |>
                  select(-date)
              })
            )
        })
      )
    
    # analyses_data |> 
    #   tabyl(detection_method)
    
    # fill analyses with non-detect on missing days
    analyses_fill <- analyses_data |> 
      mutate(
        n_detections = map_int(detections, function (x) {
          if (is.null(x)) {
            return(0)
          }
          nrow(x)
        }),
        detections = pmap(list(detections, analysis_start_date, analysis_end_date), function (detections, start_date, end_date) {
          analysis_dates <- seq.Date(start_date, end_date, by = "day") 
          if (is.null(detections)) {
            detections <- tibble(
              date = analysis_dates,
              presence = "n",
              locations = list(NULL)
            )
            return(detections)
          }
          detections |> 
            complete(date = analysis_dates, fill = list(presence = "n", locations = list(NULL)))
        }),
        n_detections_filled = map_int(detections, nrow) - n_detections
      )
    analyses <- analyses_fill |> 
      select(-n_detections, -n_detections_filled)

    detections <- analyses |> 
      left_join(
        deployments |> 
          select(deployment_id, deployment_type),
        by = "deployment_id"
      ) |>
      unnest(detections)
    # tabyl(detections, species, presence)

    stationary_detections <- detections |> 
      filter(deployment_type == "STATIONARY")
    mobile_detections <- detections |> 
      filter(deployment_type == "MOBILE") |> 
      rename(daily_presence = presence) |> 
      select(organization_code, analysis_id, deployment_id, date, locations) |>
      unnest(locations)
    # skimr::skim(mobile_detections)
    # mobile_detections |> 
    #   filter(is.na(latitude)) |> 
    #   tabyl(analysis_id)
    
    stopifnot(
      # sites
      all(sites$site_id %in% na.omit(deployments$site_id)),
      all(!is.na(sites$site_latitude) & !is.na(sites$site_longitude)),

      # deployments
      all(na.omit(deployments$site_id) %in% sites$site_id),
      all(deployments$deployment_type == "MOBILE" | (!is.na(deployments$latitude) & !is.na(deployments$longitude))),

      # tracks
      all(tracks$deployment_id %in% deployments$deployment_id),

      # analyses
      all(analyses$deployment_id %in% deployments$deployment_id),
      all(map_int(analyses$detections, nrow) > 0),

      # mobile detections
      all(!is.na(mobile_detections$latitude) & !is.na(mobile_detections$longitude))
    )
    
    list(
      sites = sites,
      deployments = deployments,
      analyses = analyses,
      tracks = tracks
    )
  }),

  tar_target(pacm_deployments_map, {
    pacm_data$deployments |> 
      filter(deployment_type == "STATIONARY") |> 
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |>
      mapview::mapview(
        label = "deployment_id",
        zcol = "organization_code",
        layer.name = "Organization"
      )
  }),
  tar_target(pacm_sites_map, {
    pacm_data$sites |> 
      st_as_sf(coords = c("site_longitude", "site_latitude"), crs = 4326) |>
      mapview::mapview(
        label = "site_id",
        zcol = "organization_code",
        layer.name = "Organization"
      )
  }),
  tar_target(pacm_tracks_map, {
    pacm_data$tracks |> 
      mapview::mapview(
        label = "track_id",
        zcol = "organization_code",
        layer.name = "Organization"
      )
  }),

  tar_target(pacm_deployments, {
    deployments <- pacm_data$deployments |> 
      select(
        organization_code,
        id = deployment_id,
        deployment_code,
        project,
        site_id,
        site,
        latitude,
        longitude,
        monitoring_start_datetime,
        monitoring_end_datetime,
        platform_type,
        deployment_type,
        water_depth_meters,
        recorder_depth_meters,
        instrument_type,
        sampling_rate_hz,
        data_poc,
      ) |> 
      mutate(
        start = as_date(monitoring_start_datetime),
        end = as_date(monitoring_end_datetime)
      ) |> 
      filter(!is.na(start))
    
    detections <- deployments |>
      transmute(id, start, end = coalesce(end, start)) |> 
      rowwise() |> 
      mutate(
        date = list(seq.Date(start, end, by = "day"))
      ) |> 
      unnest(date) |> 
      select(-start, -end) |> 
      mutate(
        species = NA_character_,
        presence = "d",
        locations = "null"
      )
    
    sites <- pacm_data$sites |> 
      filter(site_id %in% deployments$site_id)

    tracks <- pacm_data$tracks |> 
      filter(deployment_id %in% deployments$id) |> 
      select(organization_code, id = deployment_id, track_id)
    
    list(
      sites = sites,
      deployments = deployments,
      detections = detections,
      tracks = tracks
    )
  }),
  tar_target(pacm_themes_species, {
    x <- list(
      beaked = c(
        "SOBW",
        "UNBW",
        "UNSBW",
        "HUBW",
        "BW53",
        "CUBW",
        "BLBW",
        "LBWH",
        "UBWA",
        "STWH",
        "BW39V",
        "PEBW",
        "BBWH",
        "DEBW",
        "BWC",
        "STBWH",
        "ANBW",
        "SBWH",
        "GTBW",
        "GEBW",
        "GOBW",
        "MMME",
        "BW43",
        "BW29",
        "TRBW",
        "BW70",
        "BWB",
        "NBWH",
        "BW41",
        "HEBW",
        "UNME",
        "STTWH",
        "BWG",
        "SHBW",
        "ARBW",
        "BW58",
        "PYBW",
        "GBWH"
      ),
      blue = "BLWH",
      dolphin = "UNDO",
      fin = "FIWH",
      gray = "GRWH",
      # harbor = "HAPO",
      humpback = "HUWH",
      kogia = "UNKO",
      minke = "MIWH",
      narw = "RIWH",
      nbhf = "NBHF",
      pilot = "PIWH",
      pwdo = "PWDO",
      risso = "GRAM",
      sei = "SEWH",
      sperm = "SPWH"
    )

    # confirm all codes in sound_sources table
    sound_source_codes <- makara_db$sound_sources$code
    stopifnot(all(unique(unlist(x)) %in% sound_source_codes))

    x
  }),
  tar_target(pacm_themes, {
    pacm_themes_species |> 
      enframe("theme", "theme_species") |> 
      mutate(
        data = map(theme_species, function (theme_species) {
          create_theme(
            data = pacm_data,
            species = theme_species
          )
        })
      ) |> 
      unnest_wider(data) |> 
      add_row(
        theme = "deployments",
        theme_species = list(NULL),
        sites = list(pacm_deployments$sites),
        deployments = list(pacm_deployments$deployments),
        detections = list(pacm_deployments$detections),
        tracks = list(pacm_deployments$tracks)
      )
  }),
  tar_target(pacm_themes_files, {
    x <- pacm_themes |> 
      mutate(
        files = pmap(list(theme, sites, deployments, detections, tracks), function (theme, sites, deployments, detections, tracks) {
          theme_dir <- file.path(pacm_dir, theme)
          if (!dir.exists(theme_dir)) {
            dir.create(theme_dir)
          }

          files <- c()
          
          sites_file <- file.path(theme_dir, "sites.json")
          if (!is.null(sites)) {
            sites |> 
              jsonlite::write_json(
                sites_file,
                auto_unbox = TRUE,
                pretty = TRUE
              )
          } else {
            list() |> 
              jsonlite::write_json(
                sites_file,
                auto_unbox = TRUE,
                pretty = TRUE
              )
          }
          
          deployments_file <- file.path(theme_dir, "deployments.json")
          if (!is.null(deployments)) {
            deployments |> 
              jsonlite::write_json(
                deployments_file,
                auto_unbox = TRUE,
                pretty = TRUE
              )
          } else {
            stop("deployments is NULL")
          }
          
          tracks_file <- file.path(theme_dir, "tracks.json")
          if (!is.null(tracks)) {
            tracks |> 
              write_sf(
                tracks_file,
                driver = "GeoJSON", 
                layer_options = "ID_FIELD=id",
                delete_dsn = TRUE
              )
          } else {
            list(features = list()) |> 
              jsonlite::write_json(
                tracks_file,
                auto_unbox = TRUE,
                pretty = TRUE
              )
          }
          
          detections_file <- file.path(theme_dir, "detections.csv")
          if (!is.null(detections)) {
            detections |> 
              mutate(
                locations = map_chr(locations, jsonlite::toJSON, null = "null")
              ) |> 
              write_csv(detections_file, na = "")
          } else {
            stop("detections is NULL")
          }
          c(sites_file, deployments_file, tracks_file, detections_file)
        })
      )
    unlist(x$files)
  }, format = "file"),

  tar_target(pacm_ref, {
    list(
      species = makara_db$sound_sources |> 
        select(code, name),
      platform_types = makara_db$platform_types |> 
        select(code, name)
    )
  }),

  tar_target(pacm_ref_files, {
    imap_chr(pacm_ref, function (data, name) {
      f <- file.path(pacm_dir, paste0(name, ".json"))
      jsonlite::write_json(data, f, auto_unbox = TRUE, pretty = TRUE)
      f
    })
  })
)