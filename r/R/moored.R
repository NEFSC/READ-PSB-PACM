targets_moored <- list(
  tar_target(moored_metadata_file, file.path(data_dir, "moored/20221115/Moored_metadata_2022-11-16.csv"), format = "file"),
  tar_target(moored_metadata, {
    moored_metadata_file %>% 
      read_csv(col_types = cols(.default = col_character())) %>% 
      remove_empty(which = "rows") %>% 
      clean_names() %>% 
      filter(!is.na(latitude)) %>% 
      transmute(
        id = coalesce(unique_id, paste0(project, "_", site_id)),
        project,
        site_id,
        latitude = parse_number(latitude),
        longitude = parse_number(longitude),
        
        monitoring_start_datetime = mdy_hm(monitoring_start_datetime),
        monitoring_end_datetime = mdy_hm(monitoring_end_datetime),
        
        platform_type = fct_recode(platform_type, mooring = "Mooring", buoy = "surface buoy"),
        platform_id,
        
        water_depth_meters = parse_number(water_depth_meters),
        recorder_depth_meters = parse_number(recorder_depth_meters),
        instrument_type,
        instrument_id,
        sampling_rate_hz = as.numeric(sampling_rate_hz),
        analysis_sampling_rate = 2000, # TODO: add to metadata
        soundfiles_timezone,
        duty_cycle_seconds,
        channel,
        qc_data,
        
        data_poc_name,
        data_poc_affiliation,
        data_poc_email,
        
        submitter_name,
        submitter_affiliation,
        submitter_email,
        submission_date = mdy(submission_date)
      )
    stopifnot(all(!duplicated(x_recorders$id)))
    x
  }),
  tar_target(moored_deployments, {
    x <- moored_deployments_file %>% 
      read_csv(col_types = cols(.default = col_character())) %>% 
      remove_empty(which = "rows") %>% 
      clean_names() %>% 
      mutate(id = coalesce(unique_id, paste0(project, "_", site_id))) %>% 
      filter(!is.na(latitude))
    x_recorders <- x %>% 
      transmute(
        id,
        project,
        site_id,
        latitude = parse_number(latitude),
        longitude = parse_number(longitude),
        
        monitoring_start_datetime = mdy_hm(monitoring_start_datetime),
        monitoring_end_datetime = mdy_hm(monitoring_end_datetime),
        
        platform_type = fct_recode(platform_type, mooring = "Mooring", buoy = "surface buoy"),
        platform_id,
        
        water_depth_meters = parse_number(water_depth_meters),
        recorder_depth_meters = parse_number(recorder_depth_meters),
        instrument_type,
        instrument_id,
        sampling_rate_hz = as.numeric(sampling_rate_hz),
        analysis_sampling_rate = 2000, # TODO: add to metadata
        soundfiles_timezone,
        duty_cycle_seconds,
        channel,
        qc_data,
        
        data_poc_name,
        data_poc_affiliation,
        data_poc_email,
        
        submitter_name,
        submitter_affiliation,
        submitter_email,
        submission_date = mdy(submission_date)
      )
    stopifnot(all(!duplicated(x_recorders$id)))
    
    x_recorders_themes <- x %>% 
      select(id, starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))) %>% 
      rename_with(
        ~ str_replace(., "_", ":"),
        starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
      ) %>%
      pivot_longer(
        starts_with(c("narw", "humpback", "sei", "fin", "blue")),
        names_to = c("theme", ".value"),
        names_sep = ":",
        values_drop_na = TRUE
      ) %>% 
      transmute(
        id,
        theme,
        detection_method,
        protocol_reference,
        call_type
      ) %>% 
      nest_by(id, .key = "themes")

    x_recorders %>% 
      left_join(x_recorders_themes, by = "id")
  }),
  tar_target(moored_detections_file, file.path(data_dir, "moored/20221115/Moored_detection_data_2022-11-15.csv"), format = "file"),
  tar_target(moored_detections, {
    x <- moored_detections_file %>% 
      read_csv(col_types = cols(.default = col_character())) %>% 
      remove_empty(which = "rows") %>% 
      clean_names() %>% 
      distinct() %>% 
      filter(!is.na(analysis_period_start_datetime))
    
    x %>%
      rename_with(
        ~ str_replace(., "_", ":"),
        starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
      ) %>% 
      pivot_longer(
        starts_with(c("narw", "humpback", "sei", "fin", "blue")),
        names_to = c("theme", ".value"),
        names_sep = ":",
        values_drop_na = TRUE
      ) %>%
      filter(!is.na(presence)) %>% 
      transmute(
        id = unique_id,
        theme,
        species = NA_character_,
        date = as_date(ymd_hms(analysis_period_start_datetime)),
        presence = fct_recode(presence, y = "Detected", n = "Not Detected", m = "Possibly Detected")
      ) %>% 
      arrange(id, theme, date) %>% 
      nest_by(id, theme, .key = "detections")
  }),
  tar_target(moored, {
    missing_deployment <- moored_detections %>% 
      anti_join(moored_deployments, by = c("id", "theme"))
    moored_deployments %>% 
      select(id, themes) %>% 
      unnest(themes) %>% 
      left_join(moored_detections, by = c("id", "themes"))
  })
)