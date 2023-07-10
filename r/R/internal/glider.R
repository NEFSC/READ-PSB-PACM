targets_glider <- list(
  tar_target(glider_deployments_file, "data/internal/glider/Glider_metadata_2022-11-15.csv", format = "file"),
  tar_target(glider_deployments, {
    df_csv <- read_csv(
      glider_deployments_file,
      col_types = cols(.default = col_character())
    ) %>% 
      janitor::clean_names()
    
    df <- df_csv %>% 
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
        theme,
        id = unique_id,
        project,
        site_id,
        latitude = NA_real_,
        longitude = NA_real_,
        
        monitoring_start_datetime = ymd(monitoring_start_datetime),
        monitoring_end_datetime = ymd(monitoring_end_datetime),
        
        platform_type = str_remove_all(platform_type, " glider"),
        platform_id,
        water_depth_meters = parse_number(water_depth_meters),
        recorder_depth_meters = parse_number(recorder_depth_meters),
        
        instrument_type,
        instrument_id,
        sampling_rate_hz = as.numeric(sampling_rate_hz),
        analysis_sampling_rate_hz = 2000,
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
        submission_date = ymd(submission_date),
        
        # species specific
        detection_method,
        protocol_reference,
        call_type
      )
    
    summary(df)
    tabyl(df, theme)
    tabyl(df, platform_type, theme)
    tabyl(df, call_type, theme)
    tabyl(df, detection_method, theme)
    tabyl(df, protocol_reference, theme)
    tabyl(df, instrument_type, theme)
    
    df
  }),
  tar_target(glider_detections_file, "data/internal/glider/Glider_detection_data_2022-11-15.csv", format = "file"),
  tar_target(glider_detections, {
    df_csv <- read_csv(
      glider_detections_file,
      col_types = cols(.default = col_character())
    ) %>% 
      clean_names() %>% 
      distinct()
    
    stopifnot(
      df_csv %>% 
        transmute(unique_id, analysis_period_start_datetime) %>% 
        count(unique_id, analysis_period_start_datetime) %>% 
        pull(n) == 1
    )
    
    # df_csv %>%
    #   transmute(unique_id, analysis_period_start_datetime) %>%
    #   count(unique_id, analysis_period_start_datetime) %>%
    #   filter(n > 1) %>%
    #   select(-n) %>%
    #   write_csv("data/qaqc/glider-duplicate-detection-datetimes.csv")
    
    # transform ---------------------------------------------------------------
    df_inst <- df_csv %>%
      rename_with(
        ~ str_replace(., "_", ":"),
        starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
      ) %>% 
      pivot_longer(
        starts_with(c("narw", "humpback", "sei", "fin", "blue")),
        names_to = c("species", ".value"),
        names_sep = ":",
        values_drop_na = TRUE
      ) %>%
      filter(!is.na(presence)) %>% 
      transmute(
        theme = species,
        id = unique_id,
        species = NA_character_,
        date = as_date(ymd_hms(analysis_period_start_datetime)),
        presence = fct_recode(presence, y = "Detected", n = "Not Detected", m = "Possibly Detected"),
        presence = ordered(presence, levels = c("y", "m", "n")), # need to order for filtering first location of each day
        analysis_period_start_datetime = ymd_hms(analysis_period_start_datetime),
        analysis_period_end_datetime = ymd_hms(analysis_period_end_datetime),
        analysis_period_effort_seconds = parse_number(analysis_period_effort_seconds),
        latitude = parse_number(latitude),
        longitude = parse_number(longitude)
      ) %>% 
      arrange(theme, id, species, date, presence, analysis_period_start_datetime)
    
    # aggregate to daily
    df_day <- df_inst %>% 
      nest(locations = c(analysis_period_start_datetime, analysis_period_end_datetime, analysis_period_effort_seconds, latitude, longitude, presence)) %>% 
      rowwise() %>% 
      mutate(
        presence = case_when(
          "y" %in% locations$presence ~ "y",
          "m" %in% locations$presence ~ "m",
          TRUE ~ "n"
        ),
        locations = list(
          locations %>%
            filter(presence %in% c("y", "m")) %>%
            mutate(date = as_date(analysis_period_start_datetime)) %>% 
            slice_head(n = 1) # only show first location if m or y
        )
      ) %>% 
      ungroup() %>% 
      relocate(locations, .after = last_col())
    
    
    # summary -----------------------------------------------------------------
    
    tabyl(df_day, theme)
    tabyl(df_day, species, theme)
    tabyl(df_day, presence, theme)
    
    # zero locations for presence = n, exactly one location for presence = y or m
    df_day %>% 
      mutate(n_locations = map_int(locations, nrow)) %>% 
      tabyl(n_locations, presence)
    
    # export ------------------------------------------------------------------
    
    list(
      data = df_inst,
      daily = df_day
    )
  }),
  tar_target(glider_tracks, {
    df_csv <- read_csv(
      glider_detections_file,
      col_types = cols(.default = col_character())
    ) %>% 
      clean_names() %>% 
      distinct()
    
    df <- df_csv %>%
      rename_with(
        ~ str_replace(., "_", ":"),
        starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
      ) %>% 
      pivot_longer(
        starts_with(c("narw", "humpback", "sei", "fin", "blue")),
        names_to = c("species", ".value"),
        names_sep = ":",
        values_drop_na = TRUE
      ) %>% 
      transmute(
        id = unique_id, 
        datetime = ymd_hms(analysis_period_start_datetime), 
        latitude = parse_number(latitude),
        longitude = parse_number(longitude)
      ) %>% 
      distinct() %>% 
      arrange(id, datetime)
    
    sf_points <- df %>% 
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
    
    sf_tracks <- sf_points %>% 
      group_by(id) %>% 
      summarise(
        start = min(datetime),
        end = max(datetime),
        do_union = FALSE,
        .groups = "drop"
      ) %>% 
      st_cast("LINESTRING")
    
    # mapview::mapview(sf_tracks)
    
    list(
      data = df,
      sf = sf_tracks
    )
  }),
  tar_target(glider, {
    detections_rds <- glider_detections$daily %>% 
      filter(id != "WHOI_GMX_201705_gmx0517_we10")
    deployments_rds <- glider_deployments
    tracks_rds <- glider_tracks$sf %>% 
      filter(id != "WHOI_GMX_201705_gmx0517_we10")
    
    
    detections_rds %>% 
      distinct(id) %>% 
      anti_join(
        deployments_rds %>% 
          distinct(id),
        by = "id"
      )
    
    # analysis period ---------------------------------------------------------
    # TODO: add analysis_start_date, analysis_end_date, analyzed to deployments metadata table
    
    analysis_periods <- detections_rds %>% 
      group_by(id) %>% 
      summarise(
        analysis_start_date = min(date),
        analysis_end_date = max(date),
        .groups = "drop"
      ) %>% 
      mutate(
        analyzed = TRUE
      )
    
    deployments_analysis <- deployments_rds %>% 
      left_join(analysis_periods, by = "id")
    
    
    # qaqc: analysis period ---------------------------------------------------
    
    # analysis periods are the same for each species
    stopifnot(
      detections_rds %>%
        group_by(theme, id) %>%
        summarise(
          analysis_start_date = min(date),
          analysis_end_date = max(date),
          .groups = "drop"
        ) %>%
        group_by(id, analysis_start_date, analysis_end_date) %>%
        summarise(
          species = str_c(theme, collapse = ","),
          .groups = "drop"
        ) %>%
        add_count(id) %>%
        filter(n > 1) %>% 
        nrow() == 0
    )
    
    # analysis period does not match monitoring period
    analysis_periods %>%
      full_join(
        deployments_analysis %>%
          distinct(id, monitoring_start_datetime, monitoring_end_datetime),
        by = "id"
      ) %>%
      mutate(
        same_start = analysis_start_date == as_date(monitoring_start_datetime),
        same_end = analysis_end_date == as_date(monitoring_end_datetime),
        difference_start_days = as.numeric(difftime(analysis_start_date, as_date(monitoring_start_datetime), units = "day")),
        difference_end_days = as.numeric(difftime(as_date(monitoring_end_datetime), analysis_end_date, units = "day")),
        monitoring_start_datetime = format(monitoring_start_datetime, "%Y-%m-%d %H:%M"),
        monitoring_end_datetime = format(monitoring_end_datetime, "%Y-%m-%d %H:%M")
      ) %>%
      select(id, starts_with("monitoring"), starts_with("analysis"), starts_with("difference"), starts_with("same")) %>%
      arrange(id) %>% 
      # filter(!same_start | !same_end) %>% view
      write_csv("data/qaqc/glider-analysis-periods.csv")
    
    
    # qaqc: deployments -------------------------------------------------------
    
    # deployments with no detections by species
    # (all are for theme=blue)
    deployments_analysis %>% 
      anti_join(
        detections_rds %>% 
          distinct(id, theme),
        by = c("id", "theme")
      )
      # tabyl(theme)
      # write_csv("data/qaqc/glider-deployments-without-detections.csv")
    
    
    # exclude deployments withou detections -----------------------------------
    
    # exclude deployments with no detection data for each theme
    deployments_analysis2 <- deployments_analysis %>% 
      semi_join(
        detections_rds %>% 
          distinct(id, theme),
        by = c("id", "theme")
      )
    tabyl(deployments_analysis2, id, theme)
    
    
    # fill missing detection days ---------------------------------------------
    # since only include detected or possibly, do not fill with NA
    
    deployments_dates <- deployments_analysis2 %>%
      transmute(
        theme,
        id,
        start = analysis_start_date, 
        end = analysis_end_date,
        n_day = as.numeric(difftime(end, start, unit = "day"))
      ) %>%
      rowwise() %>%
      mutate(
        date = list(seq.Date(start, end, by = "day"))
      ) %>%
      unnest(date)
    
    # detections that are outside the deployment analysis period (none)
    stopifnot(
      detections_rds %>%
        anti_join(deployments_dates, by = c("theme", "id", "date")) %>% 
        nrow() == 0
    )
    
    # deployment monitoring days with no detection data (add rows with presence="na")
    deployments_dates %>% 
      anti_join(detections_rds, by = c("id", "date")) %>% 
      distinct(theme, id, start, end, date) %>% 
      select(theme, id = id, analysis_start_date = start, analysis_end_date = end, date) %>%
      arrange(theme, id, analysis_start_date, date) %>%
      # tabyl(id, theme)
      write_csv("data/qaqc/glider-missing-dates.csv")
    
    detections <- deployments_dates %>%
      select(theme, id, date) %>%
      full_join(
        detections_rds,
        by = c("theme", "id", "date")
      ) %>%
      mutate(
        presence = ordered(coalesce(presence, "na"), levels = c("y", "m", "n", "na"))
      )
    
    
    # summary -----------------------------------------------------------------
    
    tabyl(detections_rds, theme, presence)
    tabyl(detections, theme, presence)
    
    
    # qaqc: detections --------------------------------------------------------
    
    # none of the deployments are all NA
    stopifnot(
      detections %>% 
        count(theme, id, presence) %>% 
        pivot_wider(names_from = "presence", values_from = "n", values_fill = 0) %>% 
        mutate(total = n + na + y + m) %>% 
        filter(na == total) %>% 
        nrow() == 0
    )
    
    
    # add tracks ----------------------------------------------------------------
    
    # no missing tracks or tracks without metadata
    stopifnot(identical(sort(tracks_rds$id), sort(unique(deployments_rds$id))))
    
    deployments <- tracks_rds %>% 
      select(-start, -end) %>% 
      inner_join(deployments_analysis2, by = c("id")) %>% 
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