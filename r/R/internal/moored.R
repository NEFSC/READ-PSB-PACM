targets_moored <- list(
  tar_target(moored_deployments_file, "data/internal/moored/Moored_metadata_2022-11-16.csv", format = "file"),
  tar_target(moored_deployments, {
    x <- read_csv(moored_deployments_file, col_types = cols(.default = col_character())) %>%
      remove_empty(which = "rows") %>%
      clean_names() %>%
      mutate(
        unique_id = coalesce(unique_id, paste0(project, "_", site_id)),
        monitoring_end_datetime = case_when(
          project == "SIROVIC_BERMUDA_201306" ~ "3/14/2014 00:00",
          TRUE ~ monitoring_end_datetime
        )
      )
    x_not_analyzed <- x %>% 
      select(project:unique_id) %>% 
      mutate(theme = "deployments", analyzed = FALSE)
    x_analyzed <- x %>% 
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
      mutate(analyzed = TRUE)
    
    bind_rows(
      x_not_analyzed,
      x_analyzed
    ) %>%
      transmute(
        theme,
        id = unique_id,
        project,
        site_id,
        latitude = parse_number(latitude),
        longitude = parse_number(longitude),
        
        monitoring_start_datetime = mdy_hm(monitoring_start_datetime),
        monitoring_end_datetime = mdy_hm(monitoring_end_datetime),
        
        platform_type = coalesce(platform_type, "Mooring"),
        platform_type = fct_recode(platform_type, mooring = "Mooring", buoy = "surface buoy"),
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
        submission_date = mdy(submission_date),
        
        # species specific
        detection_method,
        protocol_reference,
        call_type,
        analyzed
      )
  }),
  tar_target(moored_detections_file, "data/internal/moored/Moored_detection_data_2022-11-15.csv", format = "file"),
  tar_target(moored_detections, {
    read_csv(moored_detections_file, col_types = cols(.default = col_character())) %>% 
      remove_empty(which = "rows") %>% 
      clean_names() %>% 
      distinct() %>% 
      filter(!is.na(analysis_period_start_datetime)) %>% 
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
        theme,
        id = unique_id,
        species = NA_character_,
        date = as_date(ymd_hms(analysis_period_start_datetime)),
        presence = fct_recode(presence, y = "Detected", n = "Not Detected", m = "Possibly Detected")
      ) %>% 
      arrange(id, theme, date)
  }),
  tar_target(moored, {
    detections <- moored_detections %>% 
      semi_join(moored_deployments, by = "id")

    analysis_periods <- detections %>%
      group_by(id) %>%
      summarise(
        analysis_start_date = min(date),
        analysis_end_date = max(date),
        .groups = "drop"
      )

    deployments_analysis <- moored_deployments %>%
      filter(!is.na(latitude), analyzed) %>%
      left_join(analysis_periods, by = "id")

    # qaqc: analysis period ---------------------------------------------------

    # analysis periods vary by species
    detections %>%
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
      arrange(id, analysis_start_date) %>%
      select(-n)
      # write_csv("data/qaqc/moored-varying-analysis-periods.csv")

    # analysis period does not match monitoring period
    analysis_periods %>%
      full_join(
        deployments_analysis %>%
          distinct(id, platform_type, monitoring_start_datetime, monitoring_end_datetime),
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
      select(id, platform_type, starts_with("monitoring"), starts_with("analysis"), starts_with("difference"), starts_with("same")) %>%
      arrange(id)
      # filter(!same_start | !same_end) %>% view
      # write_csv("data/qaqc/moored-analysis-periods.csv")

    # fill: missing detections -------------------------------------------------
    # presence = na for any date missing within the analysis period

    # dates over analysis period of each deployment
    deployments_dates <- deployments_analysis %>%
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

    # fill missing detection days with presence = na
    # and add empty locations
    detections <- deployments_dates %>%
      select(theme, id, date) %>%
      full_join(
        detections,
        by = c("theme", "id", "date")
      ) %>%
      mutate(
        presence = ordered(coalesce(presence, "na"), levels = c(levels(presence), "na")),
        locations = map(theme, ~ NULL)
      )


    # qaqc: detections --------------------------------------------------------

    # no detections are outside the deployment analysis period
    stopifnot(
      detections %>%
        anti_join(deployments_dates, by = c("theme", "id", "date")) %>%
        nrow() == 0
    )

    # deployment monitoring days with no detection data (filled with presence = na)
    deployments_dates %>%
      anti_join(detections, by = c("id", "date")) %>%
      distinct(theme, id, start, end, date) %>%
      select(theme, id = id, analysis_start_date = start, analysis_end_date = end, date) %>%
      arrange(theme, id, analysis_start_date, date)
      # write_csv("data/qaqc/moored-missing-dates.csv")
    # tabyl(id, theme)

    # none of the deployments are all NA
    stopifnot(
      detections %>%
        count(theme, id, presence) %>%
        pivot_wider(names_from = "presence", values_from = "n", values_fill = 0) %>%
        mutate(total = n + na + y + m) %>%
        filter(na == total) %>%
        nrow() == 0
    )


    # summary -----------------------------------------------------------------

    tabyl(detections, theme, presence) # before fill
    tabyl(detections, theme, presence)     # after fill


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
      bind_rows(filter(moored_deployments, !analyzed, !is.na(latitude))) %>% 
      distinct(id, latitude, longitude) %>%
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

    mapview::mapview(deployments_sf, legend = FALSE)

    deployments <- deployments_sf %>%
      left_join(
        deployments_analysis %>%
          bind_rows(filter(moored_deployments, !analyzed, !is.na(latitude))), 
        by = "id"
      ) %>%
      mutate(deployment_type = "stationary") %>%
      relocate(deployment_type, geometry, .after = last_col())


    # qaqc --------------------------------------------------------------------

    qaqc_dataset(deployments, detections)


    # export ------------------------------------------------------------------

    list(
      deployments = deployments,
      detections = detections
    )
  })
)