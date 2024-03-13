# DAVIS_20231122: 2015-2023 RIWH

targets_davis_20231122 <- list(
  tar_target(davis_20231122_ids_file, "data/internal/DAVIS_20231122/deployment-ids.csv", format = "file"),
  tar_target(davis_20231122_ids, {
    read_csv(davis_20231122_ids_file, col_types = cols(.default = col_character())) %>%
      remove_empty(which = "rows") %>%
      clean_names() %>% 
      filter(!is.na(old_unique_id)) %>% 
      select(old_unique_id, id = new_unique_id)
  }),
  
  tar_target(davis_20231122_header_file, "data/internal/DAVIS_20231122/DAVIS_2023-11-22_HEADER_RIWH_2015-2023.csv", format = "file"),
  tar_target(davis_20231122_header, {
    read_csv(davis_20231122_header_file, col_types = cols(.default = col_character())) %>%
      remove_empty(which = "rows") %>%
      clean_names()
  }),
  tar_target(davis_20231122_deployments, {
    x <- davis_20231122_header %>% 
      left_join(
        db_deployments %>% 
          select(
            deployment_id, 
            inventory_id,
            project_id, 
            site_id, 
            platform_no,
            latitude_ddg_deployment, 
            longitude_ddg_deployment,
            depth_water_meters,
            depth_recorder_meters
          ),
        by = "deployment_id"
      ) %>% 
      left_join(
        db_inventory %>% 
          select(inventory_id, inventory_type_id, item_description),
        by = "inventory_id"
      ) %>% 
      left_join(
        db_inventory_types %>% 
          select(inventory_type_id, inventory_type_name),
        by = "inventory_type_id"
      ) %>% 
      left_join(
        db_sites %>% 
          select(site_id, site_name),
        by = "site_id"
      ) %>% 
      left_join(
        db_projects %>% 
          select(project_id, project_name),
        by = "project_id"
      ) %>% 
      left_join(
        db_recordings %>% 
          select(recording_id, sample_rate_khz, soundfiles_timezone, channel, recording_start_utc, recording_end_utc),
        by = "recording_id"
      ) %>% 
      left_join(
        davis_20231122_detail %>% 
          select(detection_header_id, call_type = pacm_call_type_code) %>% 
          distinct(),
        by = "detection_header_id"
      )
    
    x2 <- x %>%
      transmute(
        theme = "narw",
        id = toupper(glue("{project_name}_{site_name}")),
        project = project_name,
        site_id = site_name,
        latitude = latitude_ddg_deployment,
        longitude = case_when(
          site_id == "SB02" & is.na(longitude_ddg_deployment) ~ -70.24228,
          TRUE ~ longitude_ddg_deployment
        ),
        
        monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
        monitoring_end_datetime = ymd_hms(monitoring_end_datetime),
        
        platform_type = case_when(
          inventory_type_name == "RECORDING DEVICE (BOTTOM-MOUNTED)" ~ "mooring",
          TRUE ~ NA_character_
        ),
        platform_id = platform_no,
        
        water_depth_meters = depth_water_meters,
        recorder_depth_meters = parse_number(depth_recorder_meters),
        instrument_type = item_description,
        instrument_id = as.character(inventory_id),
        sampling_rate_hz = sample_rate_khz * 1000,
        soundfiles_timezone,
        duty_cycle_seconds = NA_character_,
        channel,
        
        data_poc_name = "Genevieve Davis",
        data_poc_affiliation = "NOAA NEFSC",
        data_poc_email = "genevieve.davis@noaa.gov",
        
        submitter_name = "Genevieve Davis",
        submitter_affiliation = "NOAA NEFSC",
        submitter_email = "genevieve.davis@noaa.gov", 
        submission_date = ymd(str_sub(submission_date, 1, 10)),
        
        # species specific
        detection_method,
        protocol_reference,
        call_type = call_type,
        analyzed = TRUE,
        qc_data = qc_processing,
        detection_header_id
      )
    x3 <- x2 %>% 
      add_count(id) %>% 
      group_by(id) %>% 
      mutate(
        id = if_else(n > 1, paste0(id, "_", row_number()), as.character(id))
      ) %>%
      ungroup() %>% 
      select(-n)
    x3 %>% 
      left_join(davis_20231122_ids, by = "id")
  }),
  
  tar_target(davis_20231122_detail_file, "data/internal/DAVIS_20231122/DAVIS_2023-11-22_DETAIL_RIWH_2015-2023.csv", format = "file"),
  tar_target(davis_20231122_detail, {
    read_csv(davis_20231122_detail_file, col_types = cols(.default = col_character())) %>%
      remove_empty(which = "rows") %>%
      clean_names()
  }),
  tar_target(davis_20231122_detections, {
    davis_20231122_detail %>%
      left_join(
        davis_20231122_deployments %>% 
          transmute(
            detection_header_id,
            id
          ),
        by = "detection_header_id"
      ) %>% 
      transmute(
        theme = "narw",
        id,
        species = NA_character_,
        date = as_date(ymd_hms(analysis_period_start_datetime)),
        presence = case_when(
          acoustic_presence == "0" ~ "n",
          acoustic_presence == "1" ~ "y",
          acoustic_presence == "2" ~ "m",
          TRUE ~ NA_character_
        )
      ) %>%
      arrange(theme, id, date)
  }),
  tar_target(davis_20231122, {
    detections <- davis_20231122_detections %>%
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

    deployments_analysis <- davis_20231122_deployments %>%
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
      bind_rows(filter(davis_20231122_deployments, !analyzed, !is.na(latitude))) %>%
      distinct(id, latitude, longitude) %>%
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

    mapview::mapview(deployments_sf, legend = FALSE)

    deployments <- deployments_sf %>%
      left_join(
        deployments_analysis %>%
          bind_rows(filter(davis_20231122_deployments, !analyzed, !is.na(latitude))),
        by = "id"
      ) %>%
      mutate(deployment_type = "stationary") %>%
      relocate(deployment_type, geometry, .after = last_col()) %>% 
      select(-detection_header_id)

    # export ------------------------------------------------------------------

    list(
      deployments = deployments,
      detections = detections
    )
  })
)