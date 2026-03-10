targets_towed <- list(
  tar_target(towed_dir, file.path(data_dir, "towed")),

  tar_target(towed_metadata_file, file.path(towed_dir, "Towed_Array_effort_Walker_Website_Daily_Resolution.xlsx"), format = "file"),
  tar_target(towed_cruise_dates, {
    read_xlsx(
      towed_metadata_file,
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
      select(-start, -end)
  }),
  tar_target(towed_hb1603_sperm_analysis, {
    tibble(
      organization_code = "NEFSC",
      deployment_id = "NEFSC:NEFSC_HB1603",
      deployment_code = "NEFSC_HB1603",
      analysis_code = "SPERM_ANALYSIS",
      recording_id = "NEFSC:NEFSC_HB1603:RECORDING_192KHZ",
      species = "SPWH",
      analysis_sampling_rate_hz = 96000,
      qc_data = "POST_PROCESSED",
      call_type = "SPWH_USC",
      detection_method = "PAMGUARD,MANUAL",
      protocol_reference = "Westell et al 2022 (In prep)"
    )
  }),
  
  tar_target(towed_metadata, {
    df_raw <- read_excel(
      towed_metadata_file,
      sheet = "Towed_array_metadata"
    ) %>% 
      janitor::clean_names()
    
    df <- df_raw |> 
      transmute(
        # deployment
        organization_code = str_sub(project, 1, 5),
        deployment_id = glue("{organization_code}:{project}"),
        deployment_code = project,
        project = NA_character_,
        site_id = NA_character_,
        latitude = NA_real_,
        longitude = NA_real_,
        monitoring_start_datetime,
        monitoring_end_datetime,
        platform_type = case_when(
          platform_type == "Towed Array, linear" ~ "TOWED_ARRAY",
          TRUE ~ NA_character_
        ),
        platform_id = NA_character_,
        water_depth_meters = NA_real_,
        deployment_type = "MOBILE",
        data_poc = case_when(
          data_poc_name == "Danielle Cholewiak, Annamaria DeAngelis" ~ "Danielle Cholewiak <danielle.cholewiak@noaa.gov>, Annamaria DeAngelis <annamaria.deangelis@noaa.gov>",
          data_poc_name == "Melissa Soldevilla, Annamaria DeAngelis" ~ "Melissa Soldevilla <melissa.soldevilla@noaa.gov>, Annamaria DeAngelis <annamaria.deangelis@noaa.gov>",
          TRUE ~ NA_character_
        ),
        # data_poc_affiliation,
        # data_poc_email,
        
        # recording
        recording_code = glue("RECORDING_{floor(sampling_rate_hz / 1e3)}KHZ"),
        recording_id = glue("{deployment_id}:{recording_code}"),
        instrument_type = case_when(
          instrument_type == "HTI-96-min & Reson" ~ "HTI-96-MIN,RESON",
          TRUE ~ toupper(instrument_type)
        ),
        device_type_codes = map(instrument_type, ~ str_split(.x, ",")[[1]]),
        instrument_id = NA_character_,
        recorder_depth_meters = NA_real_,
        sampling_rate_hz,
        soundfiles_timezone = NA_character_,
        duty_cycle_seconds = NA_real_,
        channel = NA_character_,
        
        # analysis
        analysis_code = case_when(
          species == "beaked" ~ "BEAKED_ANALYSIS",
          species == "sperm" ~ "SPERM_ANALYSIS",
          species == "kogia" ~ "KOGIA_ANALYSIS",
          TRUE ~ NA_character_
        ),
        analysis_id = glue("{deployment_id}:NEFSC:{analysis_code}"),
        species = case_when(
          species == "beaked" ~ "BEAKED",
          species == "sperm" ~ "SPWH",
          species == "kogia" ~ "UNKO",
          TRUE ~ NA_character_
        ),
        qc_data = case_when(
          qc_data == "post-processed" ~ "POST_PROCESSED",
          qc_data == "real-time monitoring" ~ "REAL_TIME",
          TRUE ~ NA_character_
        ),
        analyzed = as.logical(analyzed),
        analysis_sampling_rate_hz,
        call_type = case_when(
          call_type == "Frequency modulated upsweep" ~ "OD_CLICK_FM",
          call_type == "Narrow band high frequency click" ~ "OD_CLICK_NBHF",
          call_type == "Usual click" ~ "SPWH_USC",
          TRUE ~ NA_character_
        ),
        detection_method = "PAMGUARD",
        protocol_reference,

        submitter_name,
        submitter_affiliation,
        submitter_email,
        submission_date = as_date(submission_date)
      ) |> 
      filter(!(species == "SPWH" & deployment_id == "NEFSC:NEFSC_HB1603")) |> 
      ungroup()
    
    tabyl(df, deployment_id, species)
    tabyl(df, platform_type, species)
    tabyl(df, call_type, species)
    tabyl(df, detection_method, species)
    tabyl(df, protocol_reference, species)
    tabyl(df, instrument_type, species)
    tabyl(df, analyzed, species)
    tabyl(df, qc_data, species)

    df
  }),
  
  tar_target(towed_deployments, {
    x <- towed_metadata |> 
      distinct(
        organization_code,
        deployment_id,
        deployment_code,
        project,
        site_id,
        latitude,
        longitude,
        monitoring_start_datetime,
        monitoring_end_datetime,
        platform_type,
        platform_id,
        deployment_type,
        water_depth_meters,
        data_poc
        # data_poc_affiliation,
        # data_poc_email,
      ) |> 
      left_join(
        towed_recordings |> 
          nest(.by = "deployment_id", .key = "recordings"),
        by = "deployment_id"
      ) |> 
      mutate(
        recorder_depth_meters = map_chr(recordings, ~ format_range(.x$recorder_depth_meters)),
        instrument_type = map_chr(recordings, ~ format_list(unlist(.x$device_type_codes))),
        sampling_rate_hz = map_chr(recordings, ~ format_range(.x$sampling_rate_hz))
      ) |> 
      select(-recordings)
    stopifnot(all(x$deployment_id %in% towed_tracks$deployment_id))
    x
  }),
  tar_target(towed_recordings, {
    towed_metadata |> 
      filter(analyzed) |> 
      transmute(
        deployment_id,
        recording_id,
        recording_code,
        device_type_codes,
        instrument_id,
        recorder_depth_meters,
        sampling_rate_hz,
        soundfiles_timezone,
        duty_cycle_seconds,
        channel
      )
  }),
  tar_target(towed_analyses, {
    x <- bind_rows(
      towed_metadata |> 
        filter(analyzed) |> 
        distinct(
          organization_code,
          deployment_id,
          deployment_code,
          recording_id,
          analysis_code,
          species,
          qc_data,
          analysis_sampling_rate_hz,
          call_type,
          detection_method,
          protocol_reference
        ),
      towed_hb1603_sperm_analysis
    ) |> 
      mutate(
        species = map(species, function (species) {
          if (species == "BEAKED") {
            c(
              "BLBW",
              "GEBW",
              "MMME",
              "GOBW",
              "SOBW",
              "TRBW",
              "UNME"
            )
          } else {
            species
          }
        })
      ) |> 
      left_join(
        towed_recordings |> 
          select(-deployment_id, -recording_code) |> 
          nest(.by = "recording_id", .key = "recordings"),
        by = "recording_id"
      ) |> 
      mutate(
        recorder_depth_meters = map_chr(recordings, ~ format_range(.x$recorder_depth_meters)),
        instrument_type = map_chr(recordings, ~ format_list(unlist(.x$device_type_codes))),
        sampling_rate_hz = map_chr(recordings, ~ format_range(.x$sampling_rate_hz))
      ) |> 
      left_join(
        towed_detections |>
          nest(daily = -c(deployment_code, analysis_code)),
        by = c("deployment_code", "analysis_code")
      )
    
    x
  }),

  tar_target(towed_deployments_pacm, {
    towed_deployments
  }),
  tar_target(towed_analyses_pacm, {
    towed_analyses |> 
      select(-recordings) |> 
      left_join(
        towed_cruise_dates |> 
          group_by(id) |> 
          summarise(dates = list(date)),
        by = c("deployment_code" = "id")
      ) |> 
      mutate(
        daily = pmap(
          list(species, dates, daily),
          function (species, dates, daily) {
            crossing(
              species = species,
              date = dates
            ) |> 
              left_join(
                daily,
                by = c("date", "species")
              ) |> 
              mutate(
                presence = coalesce(presence, "n")
              ) |> 
              nest(detections = -species) |> 
              mutate(
                detections = map(detections, function (detections) {
                  detections |> 
                    select(all_of(pacm_names$analyses_detections))
                })
              )
          }
        ),
        analysis_period = map(dates, function (dates) {
          list(
            analysis_start_date = min(dates),
            analysis_end_date = max(dates)
          )
        })
      ) |> 
      unnest_wider(analysis_period) |>
      select(-species, -dates, -recording_id) |> 
      unnest(daily) |> 
      mutate(
        analysis_id = glue("{deployment_id}:NEFSC:{analysis_code}:{species}")
      ) |> 
      select(all_of(pacm_names$analyses))
  }),
  tar_target(towed_tracks_pacm, {
    towed_tracks |> 
      select(all_of(pacm_names$tracks))
  }),

  tar_target(towed_pacm, {
    stopifnot(
      identical(
        sort(unique(towed_deployments_pacm$deployment_id)),
        sort(unique(towed_analyses_pacm$deployment_id)),
      ),
      identical(
        sort(unique(towed_deployments_pacm$deployment_id)),
        sort(unique(towed_tracks_pacm$deployment_id)),
      )
    )
    list(
      sites = NULL,
      deployments = towed_deployments_pacm,
      analyses = towed_analyses_pacm,
      tracks = towed_tracks_pacm
    )
  })
)