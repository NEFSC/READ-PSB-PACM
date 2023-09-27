# sperm whale at moorings

targets_nefsc_20230926 <- list(
  tar_target(nefsc_20230926_metadata_file, "data/internal/NEFSC_20230926/NEFSC_2023-09-26_METADATA.csv", format = "file"),
  tar_target(nefsc_20230926_metadata, {
    x <- read_csv(nefsc_20230926_metadata_file, col_types = cols(.default = col_character())) %>%
      remove_empty(which = "rows") %>%
      clean_names()
    
    x %>%
      transmute(
        theme = "sperm",
        id = unique_id,
        project,
        site_id,
        latitude = parse_number(latitude),
        longitude = parse_number(longitude),
        
        monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
        monitoring_end_datetime = ymd_hms(monitoring_end_datetime),
        
        platform_type = tolower(platform_type),
        platform_id = NA_character_,
        
        water_depth_meters = parse_number(water_depth_meters),
        recorder_depth_meters = parse_number(recorder_depth_meters),
        instrument_type,
        instrument_id,
        sampling_rate_hz = as.numeric(samplte_rate_hz),
        analysis_sampling_rate_hz = 2000,
        soundfiles_timezone,
        duty_cycle_seconds = NA_character_,
        channel,
        
        data_poc_name,
        data_poc_affiliation,
        data_poc_email,
        
        submitter_name,
        submitter_affiliation,
        submitter_email,
        submission_date = ymd(submission_date),
        
        # species specific
        # detection_method,
        # protocol_reference,
        # call_type,
        # analyzed
        # qc_data
      )
  }),
  tar_target(nefsc_20230926_deployments, {
    x <- nefsc_20230926_detections_raw %>% 
      distinct(id = unique_id, detection_method, protocol_reference, qc_data = qc_processing) %>% 
      mutate(call_type = "Usual click", analyzed = TRUE)
    nefsc_20230926_metadata %>% 
      left_join(x, by = "id")
  }),
  tar_target(nefsc_20230926_detections_file, "data/internal/NEFSC_20230926/NEFSC_2023-09-26_DETECTIONS.csv", format = "file"),
  tar_target(nefsc_20230926_detections_raw, {
    read_csv(nefsc_20230926_detections_file, col_types = cols(.default = col_character())) %>% 
      remove_empty(which = "rows") %>% 
      clean_names() %>% 
      distinct()
  }),
  tar_target(nefsc_20230926_detections, {
    nefsc_20230926_detections_raw %>% 
      transmute(
        theme = "sperm",
        id = unique_id,
        species = NA_character_,
        date = as_date(ymd_hms(analysis_period_start_datetime)),
        presence = fct_recode(acoustic_presence, y = "D", n = "N")
      ) %>%
      arrange(id, theme, date)
  }),
  tar_target(nefsc_20230926, {
    detections <- nefsc_20230926_detections %>% 
      mutate(
        locations = map(theme, ~ NULL)
      )
    
    analysis_periods <- detections %>%
      group_by(id) %>%
      summarise(
        analysis_start_date = min(date),
        analysis_end_date = max(date),
        .groups = "drop"
      )
    
    deployments_analysis <- nefsc_20230926_deployments %>%
      filter(!is.na(latitude), analyzed) %>%
      left_join(analysis_periods, by = "id")
    
    # qaqc: analysis period ---------------------------------------------------
    # 
    # deployments_analysis %>%
    #   transmute(
    #     id, 
    #     monitoring_start_date = as_date(monitoring_start_datetime), 
    #     monitoring_end_date = as_date(monitoring_end_datetime),
    #     monitoring_n_days = as.numeric(monitoring_end_date - monitoring_start_date + 1),
    #     analysis_start_date,
    #     analysis_end_date,
    #     analysis_n_days = as.numeric(analysis_end_date - analysis_start_date + 1),
    #     delta_days = monitoring_n_days - analysis_n_days
    #   ) %>%
    #   left_join(
    #     count(detections, id, name = "n_detections"),
    #     by = "id"
    #   ) %>% 
    #   view()
    # 
    # analysis period does not match monitoring period
    # analysis_periods %>%
    #   full_join(
    #     deployments_analysis %>%
    #       distinct(id, platform_type, monitoring_start_datetime, monitoring_end_datetime),
    #     by = "id"
    #   ) %>%
    #   mutate(
    #     same_start = analysis_start_date == as_date(monitoring_start_datetime),
    #     same_end = analysis_end_date == as_date(monitoring_end_datetime),
    #     difference_start_days = as.numeric(difftime(analysis_start_date, as_date(monitoring_start_datetime), units = "day")),
    #     difference_end_days = as.numeric(difftime(as_date(monitoring_end_datetime), analysis_end_date, units = "day")),
    #     monitoring_start_datetime = format(monitoring_start_datetime, "%Y-%m-%d %H:%M"),
    #     monitoring_end_datetime = format(monitoring_end_datetime, "%Y-%m-%d %H:%M")
    #   ) %>%
    #   select(id, platform_type, starts_with("monitoring"), starts_with("analysis"), starts_with("difference"), starts_with("same")) %>%
    #   arrange(id)
    # filter(!same_start | !same_end) %>% view
    
    # summary -----------------------------------------------------------------
    
    tabyl(detections, theme, presence) # before fill
    
    # deployments geom --------------------------------------------------------
    
    # no missing id, latitude, longitude
    stopifnot(
      all(
        deployments_analysis %>%
          distinct(id, latitude, longitude) %>%
          complete.cases()
      )
    )
    
    deployments_sf <- deployments_analysis %>%
      bind_rows(filter(nefsc_20230926_deployments, !analyzed, !is.na(latitude))) %>% 
      distinct(id, latitude, longitude) %>%
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
    
    mapview::mapview(deployments_sf, legend = FALSE)
    
    deployments <- deployments_sf %>%
      left_join(
        deployments_analysis %>%
          bind_rows(filter(nefsc_20230926_deployments, !analyzed, !is.na(latitude))), 
        by = "id"
      ) %>%
      mutate(deployment_type = "stationary") %>%
      relocate(deployment_type, geometry, .after = last_col())
    
    # export ------------------------------------------------------------------
    
    list(
      deployments = deployments,
      detections = detections
    )
  })
)