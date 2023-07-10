targets_towed <- list(
  tar_target(towed_deployments_orig_file, "data/internal/towed/Towed_Array_effort_Walker_Website_Daily_Resolution.xlsx", format = "file"),
  tar_target(towed_deployments_orig, {
    df_raw <- read_excel(
      towed_deployments_orig_file,
      sheet = "Towed_array_metadata"
    ) %>% 
      janitor::clean_names()
    
    cruise_dates <- read_xlsx(
      towed_deployments_orig_file,
      sheet = "Cruise_dates"
    ) %>% 
      clean_names() %>% 
      mutate(across(c(start, end), as_date)) %>% 
      transmute(
        id = if_else(
          cruise %in% c("GU1303", "GU1605"),
          str_c("SEFSC_", cruise, sep = ""),
          str_c("NEFSC_", cruise, sep = "")
        ),
        start,
        end
      ) %>% 
      arrange(id, start) %>% 
      group_by(id) %>% 
      mutate(leg = row_number()) %>% 
      ungroup() %>% 
      rowwise() %>% 
      mutate(
        date = list(seq.Date(start, end, by = "day"))
      ) %>% 
      unnest(date) %>% 
      select(-start, -end) %>% 
      nest(cruise_dates = c(leg, date))
    
    # transform -------------------------------------------------------------------
    
    df <- df_raw %>% 
      transmute(
        theme = species,
        id = project,
        project,
        site_id = NA_character_,
        latitude = NA_real_,
        longitude = NA_real_,
        
        monitoring_start_datetime = as_date(monitoring_start_datetime),
        monitoring_end_datetime = as_date(monitoring_end_datetime),
        
        platform_type = case_when(
          platform_type == "Towed Array, linear" ~ "towed",
          TRUE ~ NA_character_
        ),
        platform_id = NA_character_,
        water_depth_meters = NA_real_,
        recorder_depth_meters = NA_real_,
        
        instrument_type,
        instrument_id = NA_character_,
        sampling_rate_hz,
        analysis_sampling_rate_hz,
        soundfiles_timezone,
        duty_cycle_seconds,
        channel = NA_character_,
        qc_data,
        
        data_poc_name,
        data_poc_affiliation,
        data_poc_email,
        
        submitter_name,
        submitter_affiliation,
        submitter_email,
        submission_date = as_date(submission_date),
        
        analyzed = as.logical(analyzed),
        call_type,
        detection_method,
        protocol_reference
      ) %>%
      left_join(cruise_dates, by = "id") %>% 
      group_by(theme, id) %>% 
      mutate(
        analysis_start_date = if_else(analyzed, ymd(map(cruise_dates, ~ as.character(min(.x$date)))), NA_Date_),
        analysis_end_date = if_else(analyzed, ymd(map(cruise_dates, ~ as.character(max(.x$date)))), NA_Date_)
      ) %>% 
      filter(!(theme == "sperm" & id == "NEFSC_HB1603")) %>% 
      ungroup()
    
    tabyl(df, theme)
    tabyl(df, platform_type, theme)
    tabyl(df, call_type, theme)
    tabyl(df, detection_method, theme)
    tabyl(df, protocol_reference, theme)
    tabyl(df, instrument_type, theme)
    tabyl(df, analyzed, theme)
    
    df_analyzed <- filter(df, analyzed)
    tabyl(df_analyzed, theme)
    tabyl(df_analyzed, platform_type, theme)
    tabyl(df_analyzed, call_type, theme)
    tabyl(df_analyzed, detection_method, theme)
    tabyl(df_analyzed, protocol_reference, theme)
    tabyl(df_analyzed, instrument_type, theme)
    tabyl(df_analyzed, analyzed, theme)
    
    df
  }),
  tar_target(towed_deployments_hb1603_sperm_file, "data/internal/towed/HB1603-sperm/NEFSC_METADATA_20220211.csv", format = "file"),
  tar_target(towed_deployments_hb1603_sperm, {
    df_raw <- read_csv(
      towed_deployments_hb1603_sperm_file,
      col_types = cols(.default = col_character())
    ) %>% 
      janitor::clean_names() %>% 
      mutate(species = "sperm", .before = everything()) %>% 
      mutate(
        unique_id  = "NEFSC_HB1603",
        monitoring_start_datetime = min(monitoring_start_datetime),
        monitoring_end_datetime = max(monitoring_end_datetime),
        sampling_rate_hz = as.numeric(sampling_rate_hz)
      ) %>% 
      distinct()
    
    cruise_dates <- read_xlsx(
      towed_deployments_orig_file,
      sheet = "Cruise_dates"
    ) %>% 
      clean_names() %>% 
      mutate(across(c(start, end), as_date)) %>% 
      filter(cruise == "HB1603") %>% 
      transmute(
        id = if_else(
          cruise %in% c("GU1303", "GU1605"),
          str_c("SEFSC_", cruise, sep = ""),
          str_c("NEFSC_", cruise, sep = "")
        ),
        start,
        end
      ) %>% 
      arrange(id, start) %>% 
      group_by(id) %>% 
      mutate(leg = row_number()) %>% 
      ungroup() %>% 
      rowwise() %>% 
      mutate(
        date = list(seq.Date(start, end, by = "day"))
      ) %>% 
      unnest(date) %>% 
      select(-start, -end) %>% 
      nest(cruise_dates = c(leg, date))
    
    # transform -------------------------------------------------------------------
    
    df <- df_raw %>% 
      transmute(
        theme = species,
        id = project,
        project,
        site_id = NA_character_,
        latitude = NA_real_,
        longitude = NA_real_,
        
        monitoring_start_datetime = as_date(monitoring_start_datetime),
        monitoring_end_datetime = as_date(monitoring_end_datetime),
        
        platform_type = case_when(
          platform_type == "Towed-array" ~ "towed",
          TRUE ~ NA_character_
        ),
        platform_id = NA_character_,
        water_depth_meters = NA_real_,
        recorder_depth_meters = NA_real_,
        
        instrument_type,
        instrument_id = NA_character_,
        sampling_rate_hz,
        analysis_sampling_rate_hz = 96000,
        soundfiles_timezone,
        duty_cycle_seconds = "continuous",
        channel = NA_character_,
        qc_data = "post-processed",
        
        data_poc_name,
        data_poc_affiliation,
        data_poc_email,
        
        submitter_name,
        submitter_affiliation = "NOAA/NEFSC",
        submitter_email,
        submission_date = as_date(submission_date),
        
        analyzed = TRUE,
        call_type = "Usual click",
        detection_method = "PAMGuard click detector; manual event selection",
        protocol_reference = "Westell et al 2022 (In prep)"
      ) %>%
      left_join(cruise_dates, by = "id") %>% 
      group_by(theme, id) %>% 
      mutate(
        analysis_start_date = if_else(analyzed, ymd(map(cruise_dates, ~ as.character(min(.x$date)))), NA_Date_),
        analysis_end_date = if_else(analyzed, ymd(map(cruise_dates, ~ as.character(max(.x$date)))), NA_Date_)
      )
    
    tabyl(df, theme)
    tabyl(df, platform_type, theme)
    tabyl(df, call_type, theme)
    tabyl(df, detection_method, theme)
    tabyl(df, protocol_reference, theme)
    tabyl(df, instrument_type, theme)
    tabyl(df, analyzed, theme)
    
    df
  }),
  tar_target(towed_deployments, {
    bind_rows(
      towed_deployments_orig,
      towed_deployments_hb1603_sperm
    ) %>% 
      arrange(id, theme)
  }),
  
  tar_target(towed, {
    detections_rds <- towed_detections$daily
    deployments_rds <- towed_deployments
    tracks_rds <- towed_tracks$sf
    
    # fill missing detection days ---------------------------------------------
    
    deployments_dates <- deployments_rds %>% 
      as_tibble() %>% 
      transmute(
        theme,
        id,
        analyzed,
        cruise_dates
      ) %>%
      unnest(cruise_dates) %>% 
      select(-leg)
    
    # no detections outside deployment cruise dates
    stopifnot(
      detections_rds %>%
        anti_join(deployments_dates, by = c("theme", "id", "date")) %>% 
        nrow() == 0
    )
    
    # deployment monitoring days with no detection data (fill with presence = n)
    deployments_dates %>% 
      filter(analyzed) %>% 
      anti_join(detections_rds, by = c("id", "date")) %>%
      tabyl(id, theme)
    
    detections <- deployments_dates %>%  
      left_join(
        detections_rds,
        by = c("theme", "id", "date")
      ) %>% 
      mutate(
        presence = if_else(analyzed, coalesce(presence, "n"), "na"),
        presence = as.character(presence)
      ) %>% 
      select(-analyzed)
    
    
    # summary -----------------------------------------------------------------
    
    tabyl(detections_rds, theme, presence)
    tabyl(detections, theme, presence)
    
    tabyl(deployments_rds, id, theme, analyzed)
    
    detections %>% 
      distinct(theme, id, date, presence) %>% 
      left_join(
        deployments_rds %>%
          select(theme, id, analyzed),
        by = c("theme", "id")
      ) %>%
      filter(analyzed) %>% 
      tabyl(id, presence, theme) %>% 
      adorn_totals(where = c("row", "col"))
    
    # number of days with presence = n
    detections %>% 
      filter(presence == "n") %>% 
      tabyl(id, theme)
    
    
    # deployments ----------------------------------------------------------------
    
    # no missing tracks or tracks without metadata
    stopifnot(identical(sort(tracks_rds$id), sort(unique(deployments_rds$id))))
    
    deployments <- tracks_rds %>% 
      select(-start, -end) %>% 
      left_join(deployments_rds, by = c("id")) %>% 
      select(-cruise_dates) %>% 
      mutate(deployment_type = "mobile") %>% 
      relocate(deployment_type, geometry, .after = last_col()) %>% 
      relocate(theme)
    
    qaqc_dataset(deployments, detections)
    
    list(
      deployments = deployments,
      detections = detections
    )
  })
)