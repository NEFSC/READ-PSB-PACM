# harbor porpoise, dolphins at moorings

targets_nefsc_20230928 <- list(
  tar_target(nefsc_20230928_metadata_file, "data/internal/NEFSC_20230928/NEFSC_2023-09-28_METADATA.csv", format = "file"),
  tar_target(nefsc_20230928_metadata, {
    x <- read_csv(nefsc_20230928_metadata_file, col_types = cols(.default = col_character())) %>%
      remove_empty(which = "rows") %>%
      clean_names()
    
    x %>%
      crossing(theme = c("harbor", "dolphin")) %>% 
      transmute(
        theme,
        id = case_when(
          unique_id == "NEFSC_MA-RI_202110_NS01_FPO" ~ "NEFSC_MA-RI_202110_NS01_FPOD",
          TRUE ~ unique_id
        ),
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
        sampling_rate_hz = parse_number(sampling_rate_hz),
        soundfiles_timezone,
        duty_cycle_seconds = NA_character_,
        channel,
        
        data_poc_name,
        data_poc_affiliation,
        data_poc_email,
        
        submitter_name,
        submitter_affiliation,
        submitter_email,
        submission_date = mdy(submission_date)
        
        # species specific
        # detection_method,
        # protocol_reference,
        # call_type,
        # analyzed
        # qc_data
      )
  }),
  tar_target(nefsc_20230928_deployments, {
    x <- nefsc_20230928_detections_raw %>% 
      distinct(
        theme, 
        id = unique_id, 
        analysis_sampling_rate_hz = parse_number(analysis_sampling_rate_hz), 
        detection_method, 
        protocol_reference, 
        call_type = call_type_code, 
        qc_data = qc_processing
      ) %>% 
      mutate(analyzed = TRUE)
    
    # metadata includes three deployments with no detections
    # nefsc_20230928_metadata %>% 
    #   anti_join(x, by = c("theme", "id")) %>% 
    #   distinct(id)
    
    stopifnot(all(x$id %in% nefsc_20230928_metadata$id))
    
    nefsc_20230928_metadata %>% 
      inner_join(x, by = c("theme", "id"))
  }),
  tar_target(nefsc_20230928_detections_harbor_file, "data/internal/NEFSC_20230928/NEFSC_2023-09-28_HarborPorpoise_DETECTIONS.csv", format = "file"),
  tar_target(nefsc_20230928_detections_harbor_raw, {
    read_csv(nefsc_20230928_detections_harbor_file, col_types = cols(.default = col_character())) %>% 
      remove_empty(which = "rows") %>% 
      clean_names() %>% 
      distinct()
  }),
  tar_target(nefsc_20230928_detections_dolphin_file, "data/internal/NEFSC_20230928/NEFSC_2023-09-28_Dolphin_DETECTIONS.csv", format = "file"),
  tar_target(nefsc_20230928_detections_dolphin_raw, {
    read_csv(nefsc_20230928_detections_dolphin_file, col_types = cols(.default = col_character())) %>% 
      remove_empty(which = "rows") %>% 
      clean_names() %>% 
      distinct()
  }),
  tar_target(nefsc_20230928_detections_raw, {
    bind_rows(
      harbor = nefsc_20230928_detections_harbor_raw,
      dolphin = nefsc_20230928_detections_dolphin_raw,
      .id = "theme"
    ) %>% 
      mutate(unique_id = str_replace(unique_id, "FPOD_Min_FPOD", "FPOD"))
  }),
  tar_target(nefsc_20230928_detections, {
    nefsc_20230928_detections_raw %>% 
      transmute(
        theme,
        id = unique_id,
        species = NA_character_,
        date = as_date(ymd_hms(analysis_period_start_datetime)),
        presence = fct_recode(acoustic_presence, y = "D", n = "N")
      ) %>%
      arrange(theme, id, date)
  }),
  tar_target(nefsc_20230928, {
    detections <- nefsc_20230928_detections %>% 
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
    
    deployments_analysis <- nefsc_20230928_deployments %>%
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

    # summary -----------------------------------------------------------------
    
    tabyl(detections, theme, presence)
    
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
      bind_rows(filter(nefsc_20230928_deployments, !analyzed, !is.na(latitude))) %>% 
      distinct(id, latitude, longitude) %>%
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
    
    mapview::mapview(deployments_sf, legend = FALSE)
    
    deployments <- deployments_sf %>%
      left_join(
        deployments_analysis %>%
          bind_rows(filter(nefsc_20230928_deployments, !analyzed, !is.na(latitude))), 
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