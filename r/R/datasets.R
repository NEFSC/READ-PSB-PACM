targets_datasets <- list(
  # NEFSC 20211216 Harbor Porpoise ----------------------------------------
  tar_target(nefsc_20211216_metadata_file, "data/nefsc/20211216-harbor-porpoise/NEFSC_METADATA_20211216.csv", format = "file"),
  tar_target(nefsc_20211216_detections_file, "data/nefsc/20211216-harbor-porpoise/NEFSC_DETECTIONDATA_20211216.csv", format = "file"),
  tar_target(nefsc_20211216_dataset, read_dataset(
    list(metadata = nefsc_20211216_metadata_file, detections = nefsc_20211216_detections_file),
    list(
      detections = function (x) {
        mutate(x, CALL_TYPE = case_when(
          CALL_TYPE == "NBHF Clicks" ~ "Narrow band high frequency click",
          TRUE ~ CALL_TYPE
        ))
      }
    ),
    refs
  )),
  tar_target(nefsc_20211216, process_dataset(nefsc_20211216_dataset, refs)),
  tar_target(nefsc_20211216_plot, plot_analyses(nefsc_20211216$analyses)),
  tar_target(nefsc_20211216_rds, {
    moored <- read_rds("data/datasets/moored.rds")
    
    deployments <- nefsc_20211216$analyses %>% 
      select(-detections) %>% 
      left_join(nefsc_20211216$recorders, by = "unique_id") %>% 
      rename(
        theme = species_group,
        id = unique_id,
        platform_id = platform_no,
        analysis_sampling_rate = analysis_sampling_rate_hz,
        qc_data = qc_processing,
        deployment_type = stationary_or_mobile
      ) %>% 
      mutate(
        platform_type = case_when(
          platform_type == "bottom-mounted" ~ "mooring",
          TRUE ~ NA_character_
        ),
        platform_type = factor(platform_type, levels = levels(moored$deployments$platform_type)),
        duty_cycle_seconds = NA_character_,
        analysis_start_date = as_date(monitoring_start_datetime),
        analysis_end_date = as_date(monitoring_end_datetime),
        analyzed = TRUE,
        submission_date = as_date(submission_date),
        channel = as.character(channel)
      ) %>% 
      select(-c(detection_software_name, detection_software_version, min_analysis_frequency_range_hz, max_analysis_frequency_range_hz, recording_duration_seconds, recording_interval_seconds, sample_bits)) %>% 
      st_as_sf(coords = c("longitude", "latitude"), remove = FALSE)
    stopifnot(
      compare_df_cols_same(moored$deployments, deployments),
      identical(sort(names(moored$deployments)), sort(names(deployments)))
    )
    
    detections <- nefsc_20211216$analyses %>% 
      select(theme = species_group, id = unique_id, detections) %>% 
      unnest(detections) %>% 
      mutate(
        species = NA_character_,
        presence = case_when(
          acoustic_presence == "D" ~ "y",
          acoustic_presence == "P" ~ "m",
          acoustic_presence == "N" ~ "n",
          acoustic_presence == "M" ~ "na",
          TRUE ~ NA_character_
        ),
        presence = factor(presence, levels = levels(moored$detections$presence)),
        locations = map(theme, ~ NULL)
      ) %>% 
      select(-acoustic_presence, -detections)
    stopifnot(
      compare_df_cols_same(moored$detections, detections),
      identical(sort(names(moored$detections)), sort(names(detections)))
    )
    
    filename <- "data/datasets/nefsc_20211216.rds"
    list(
      deployments = deployments,
      detections = detections
    ) %>% 
      write_rds(filename)
    filename
  }, format = "file"),

  # NEFSC 20220211 HB1603 Sperm Whales ------------------------------------
  tar_target(nefsc_20220211_metadata_file, "data/nefsc/20220211-hb1603/NEFSC_METADATA_20220211.csv", format = "file"),
  tar_target(nefsc_20220211_detections_file, "data/nefsc/20220211-hb1603/NEFSC_DETECTIONS_20220211.csv", format = "file"),
  tar_target(nefsc_20220211_tracks_file, "data/nefsc/20220211-hb1603/NEFSC_GPS_20220211.csv", format = "file"),
  tar_target(nefsc_20220211_dataset, read_dataset(
    list(metadata = nefsc_20220211_metadata_file, detections = nefsc_20220211_detections_file, tracks = nefsc_20220211_tracks_file),
    list(
      metadata = function (x) { mutate(x, SUBMISSION_DATE = "2022-02-11T00:00:00-0500") },
      detections = function (x) { mutate(x, CALL_TYPE = NA_character_) }
    ),
    refs
  )),
  tar_target(nefsc_20220211, process_dataset(nefsc_20220211_dataset, refs)),
  tar_target(nefsc_20220211_plot, plot_analyses(nefsc_20220211$analyses)),
  tar_target(nefsc_20220211_rds, {
    towed <- read_rds("data/datasets/towed.rds")

    deployments <- nefsc_20220211$analyses %>%
      select(-detections) %>%
      left_join(nefsc_20220211$recorders, by = "unique_id") %>%
      rename(
        theme = species_group,
        id = unique_id,
        platform_id = platform_no,
        # analysis_sampling_rate = analysis_sampling_rate_hz,
        qc_data = qc_processing,
        deployment_type = stationary_or_mobile
      ) %>%
      mutate(
        platform_type = case_when(
          platform_type == "bottom-mounted" ~ "mooring",
          platform_type == "towed-array" ~ "towed",
          TRUE ~ NA_character_
        ),
        duty_cycle_seconds = NA_character_,
        analysis_start_date = as_date(monitoring_start_datetime),
        analysis_end_date = as_date(monitoring_end_datetime),
        analyzed = TRUE,
        submission_date = as_date(submission_date),
        channel = as.character(channel),
        across(c(monitoring_start_datetime, monitoring_end_datetime), as_date)
      ) %>%
      select(-c(detection_software_name, detection_software_version, min_analysis_frequency_range_hz, max_analysis_frequency_range_hz, recording_duration_seconds, recording_interval_seconds, sample_bits))
    deployments <- nefsc_20220211$tracks %>% 
      select(-c(start, end)) %>% 
      rename(id = unique_id) %>% 
      left_join(deployments, by = c("id")) %>% 
      relocate(geometry, .after = last_col())
    stopifnot(
      compare_df_cols_same(towed$deployments, deployments),
      identical(sort(names(towed$deployments)), sort(names(deployments)))
    )

    detections <- nefsc_20220211$analyses %>%
      select(theme = species_group, id = unique_id, detections) %>%
      unnest(detections) %>%
      mutate(
        species = NA_character_,
        presence = case_when(
          acoustic_presence == "D" ~ "y",
          acoustic_presence == "P" ~ "m",
          acoustic_presence == "N" ~ "n",
          acoustic_presence == "M" ~ "na",
          TRUE ~ NA_character_
        ),
        locations = map(detections, function (x) {
          if (is.null(x)) {
            return(tibble())
          }
          x %>%
            transmute(
              analysis_period_start_datetime,
              analysis_period_end_datetime,
              analysis_period_effort_seconds,
              latitude,
              longitude,
              presence = case_when(
                acoustic_presence == "D" ~ "y",
                acoustic_presence == "P" ~ "m",
                acoustic_presence == "N" ~ "n",
                acoustic_presence == "M" ~ "na",
                TRUE ~ NA_character_
              )
            )
        })
      ) %>%
      select(-acoustic_presence, -detections)
    stopifnot(
      compare_df_cols_same(towed$detections, detections),
      identical(sort(names(towed$detections)), sort(names(detections))),
      compare_df_cols_same(towed$detections$locations[[2]], detections$locations[[2]]),
      identical(sort(names(towed$detections$locations[[2]])), sort(names(detections$locations[[2]])))
    )

    filename <- "data/datasets/nefsc_20220211.rds"
    list(
      deployments = deployments,
      detections = detections
    ) %>%
      write_rds(filename)
    filename
  }, format = "file"),

  # DFO 20211124 Beaked Whales --------------------------------------------
  tar_target(dfo_20211124_metadata_file, "data/dfo/dfo-20211124/DFOCA_METADATA_20211124.csv", format = "file"),
  tar_target(dfo_20211124_detections_files, list.files("data/dfo/dfo-20211124/detections/", full.names = TRUE), format = "file"),
  tar_target(dfo_20211124_dataset, read_dataset(
    list(metadata = dfo_20211124_metadata_file, detections = dfo_20211124_detections_files),
    list(
      metadata = function (x) { mutate(x, SUBMISSION_DATE = "2021-11-24T11:00:00-05:00") }
    ),
    refs
  )),
  tar_target(dfo_20211124, process_dataset(dfo_20211124_dataset, refs)),
  tar_target(dfo_20211124_plot, plot_analyses(dfo_20211124$analyses)),
  tar_target(dfo_20211124_rds, {
    towed <- read_rds("data/datasets/towed.rds")
    moored <- read_rds("data/datasets/moored.rds")
    
    deployments <- dfo_20211124$analyses %>% 
      select(-detections) %>% 
      left_join(dfo_20211124$recorders, by = "unique_id") %>% 
      rename(
        theme = species_group,
        id = unique_id,
        platform_id = platform_no,
        analysis_sampling_rate = analysis_sampling_rate_hz,
        qc_data = qc_processing,
        deployment_type = stationary_or_mobile
      ) %>% 
      mutate(
        platform_type = case_when(
          platform_type == "bottom-mounted" ~ "mooring",
          TRUE ~ NA_character_
        ),
        platform_type = factor(platform_type, levels = levels(moored$deployments$platform_type)),
        duty_cycle_seconds = NA_character_,
        analysis_start_date = as_date(monitoring_start_datetime),
        analysis_end_date = as_date(monitoring_end_datetime),
        analyzed = TRUE,
        submission_date = as_date(submission_date),
        channel = as.character(channel)
      ) %>% 
      select(-c(detection_software_name, detection_software_version, min_analysis_frequency_range_hz, max_analysis_frequency_range_hz, recording_duration_seconds, recording_interval_seconds, sample_bits)) %>% 
      st_as_sf(coords = c("longitude", "latitude"), remove = FALSE)
    stopifnot(
      compare_df_cols_same(moored$deployments, deployments),
      identical(sort(names(moored$deployments)), sort(names(deployments)))
    )
    
    detections <- dfo_20211124$analyses %>% 
      select(theme = species_group, id = unique_id, detections) %>% 
      unnest(detections) %>% 
      mutate(
        species = case_when(
          species == "HYAM" ~ "Northern Bottlenose",
          species == "MEBI" ~ "Sowerby's",
          species == "MMME" ~ "Unid. Mesoplodon",
          species == "ZICA" ~ "Cuvier's",
          TRUE ~ NA_character_
        ),
        presence = case_when(
          acoustic_presence == "D" ~ "y",
          acoustic_presence == "P" ~ "m",
          acoustic_presence == "N" ~ "n",
          acoustic_presence == "M" ~ "na",
          TRUE ~ NA_character_
        ),
        presence = factor(presence, levels = levels(moored$detections$presence)),
        locations = map(theme, ~ NULL)
      ) %>% 
      select(-acoustic_presence, -detections)
    stopifnot(
      compare_df_cols_same(moored$detections, detections),
      identical(sort(names(moored$detections)), sort(names(detections)))
    )
    
    filename <- "data/datasets/dfo_20211124.rds"
    list(
      deployments = deployments,
      detections = detections
    ) %>% 
      write_rds(filename)
    filename
  }, format = "file"),
  
  # NYDEC 20220407 Baleen Whales --------------------------------------------
  tar_target(nydec_20220407_metadata_file, "data/nydec/20220407-baleen/NYDEC_METADATA_20220407.csv", format = "file"),
  tar_target(nydec_20220407_detections_file, "data/nydec/20220321-baleen/NYDEC_DETECTIONDATA_20220321.csv", format = "file"),
  tar_target(nydec_20220407_dataset, {
    read_dataset(
      list(metadata = nydec_20220407_metadata_file, detections = nydec_20220407_detections_file),
      list(
        detections = function (x) { mutate(x, ANALYSIS_SAMPLING_RATE_HZ = coalesce(ANALYSIS_SAMPLING_RATE_HZ, "2000")) }
      ),
      refs
    )
  }),
  tar_target(nydec_20220407, process_dataset(nydec_20220407_dataset, refs)),
  tar_target(nydec_20220407_plot, plot_analyses(nydec_20220407$analyses)),
  tar_target(nydec_20220407_rds, {
    moored <- read_rds("data/datasets/moored.rds")
    
    deployments <- nydec_20220407$analyses %>% 
      select(-detections) %>% 
      left_join(nydec_20220407$recorders, by = "unique_id") %>% 
      rename(
        theme = species_group,
        id = unique_id,
        platform_id = platform_no,
        analysis_sampling_rate = analysis_sampling_rate_hz,
        qc_data = qc_processing,
        deployment_type = stationary_or_mobile
      ) %>% 
      mutate(
        platform_type = case_when(
          platform_type == "bottom-mounted" ~ "mooring",
          TRUE ~ NA_character_
        ),
        platform_type = factor(platform_type, levels = levels(moored$deployments$platform_type)),
        duty_cycle_seconds = NA_character_,
        analysis_start_date = as_date(monitoring_start_datetime),
        analysis_end_date = as_date(monitoring_end_datetime),
        analyzed = TRUE,
        submission_date = as_date(submission_date),
        channel = as.character(channel)
      ) %>% 
      select(-c(detection_software_name, detection_software_version, min_analysis_frequency_range_hz, max_analysis_frequency_range_hz, recording_duration_seconds, recording_interval_seconds, sample_bits)) %>% 
      st_as_sf(coords = c("longitude", "latitude"), remove = FALSE)
    stopifnot(
      compare_df_cols_same(moored$deployments, deployments),
      identical(sort(names(moored$deployments)), sort(names(deployments)))
    )
    
    detections <- nydec_20220407$analyses %>% 
      select(theme = species_group, id = unique_id, detections) %>% 
      unnest(detections) %>% 
      mutate(
        species = NA_character_,
        presence = case_when(
          acoustic_presence == "D" ~ "y",
          acoustic_presence == "P" ~ "m",
          acoustic_presence == "N" ~ "n",
          acoustic_presence == "M" ~ "na",
          TRUE ~ NA_character_
        ),
        presence = factor(presence, levels = levels(moored$detections$presence)),
        locations = map(theme, ~ NULL)
      ) %>% 
      select(-acoustic_presence, -detections)
    stopifnot(
      compare_df_cols_same(moored$detections, detections),
      identical(sort(names(moored$detections)), sort(names(detections)))
    )
    
    filename <- "data/datasets/nydec_20220407.rds"
    list(
      deployments = deployments,
      detections = detections
    ) %>% 
      write_rds(filename)
    filename
  }, format = "file"),
  
  # UCORN 20220214 Baleen Whales --------------------------------------------
  tar_target(ucorn_20220214_metadata_file, "data/ucorn/20220214/UCORN_METADATA_20220214.csv", format = "file"),
  tar_target(ucorn_20220214_detections_file, "data/ucorn/20220214/UCORN_DETECTIONDATA_20220217.csv", format = "file"),
  tar_target(ucorn_20220214_dataset, read_dataset(
    list(metadata = ucorn_20220214_metadata_file, detections = ucorn_20220214_detections_file),
    list(),
    refs
  )),
  tar_target(ucorn_20220214, process_dataset(ucorn_20220214_dataset, refs)),
  tar_target(ucorn_20220214_plot, plot_analyses(ucorn_20220214$analyses)),
  tar_target(ucorn_20220214_rds, {
    moored <- read_rds("data/datasets/moored.rds")
    
    deployments <- ucorn_20220214$analyses %>% 
      select(-detections) %>% 
      left_join(ucorn_20220214$recorders, by = "unique_id") %>% 
      rename(
        theme = species_group,
        id = unique_id,
        platform_id = platform_no,
        analysis_sampling_rate = analysis_sampling_rate_hz,
        qc_data = qc_processing,
        deployment_type = stationary_or_mobile
      ) %>% 
      mutate(
        platform_type = case_when(
          platform_type == "bottom-mounted" ~ "mooring",
          TRUE ~ NA_character_
        ),
        platform_type = factor(platform_type, levels = levels(moored$deployments$platform_type)),
        duty_cycle_seconds = NA_character_,
        analysis_start_date = as_date(monitoring_start_datetime),
        analysis_end_date = as_date(monitoring_end_datetime),
        analyzed = TRUE,
        submission_date = as_date(submission_date),
        channel = as.character(channel)
      ) %>% 
      select(-c(detection_software_name, detection_software_version, min_analysis_frequency_range_hz, max_analysis_frequency_range_hz, recording_duration_seconds, recording_interval_seconds, sample_bits)) %>% 
      st_as_sf(coords = c("longitude", "latitude"), remove = FALSE)
    stopifnot(
      compare_df_cols_same(moored$deployments, deployments),
      identical(sort(names(moored$deployments)), sort(names(deployments)))
    )
    
    detections <- ucorn_20220214$analyses %>% 
      select(theme = species_group, id = unique_id, detections) %>% 
      unnest(detections) %>% 
      mutate(
        species = NA_character_,
        presence = case_when(
          acoustic_presence == "D" ~ "y",
          acoustic_presence == "P" ~ "m",
          acoustic_presence == "N" ~ "n",
          acoustic_presence == "M" ~ "na",
          TRUE ~ NA_character_
        ),
        presence = factor(presence, levels = levels(moored$detections$presence)),
        locations = map(theme, ~ NULL)
      ) %>% 
      select(-acoustic_presence, -detections)
    stopifnot(
      compare_df_cols_same(moored$detections, detections),
      identical(sort(names(moored$detections)), sort(names(detections)))
    )
    
    filename <- "data/datasets/ucorn_20220214.rds"
    list(
      deployments = deployments,
      detections = detections
    ) %>% 
      write_rds(filename)
    filename
  }, format = "file"),
  
  # UCORN 20220302 Baleen Whales --------------------------------------------
  tar_target(ucorn_20220302_metadata_file, "data/ucorn/20220302/UCORN_METADATA_20220302.csv", format = "file"),
  tar_target(ucorn_20220302_detections_file, "data/ucorn/20220302/UCORN_DETECTIONDATA_20220302.csv", format = "file"),
  tar_target(ucorn_20220302_dataset, read_dataset(
    list(metadata = ucorn_20220302_metadata_file, detections = ucorn_20220302_detections_file),
    list(
      metadata = function (x) {
        x %>%
          mutate(
            across(c(MONITORING_START_DATETIME, MONITORING_END_DATETIME), ~ as.character(mdy_hm(.x)))
          )
      }
    ),
    refs
  )),
  tar_target(ucorn_20220302, process_dataset(ucorn_20220302_dataset, refs)),
  tar_target(ucorn_20220302_plot, plot_analyses(ucorn_20220302$analyses)),
  tar_target(ucorn_20220302_rds, {
    moored <- read_rds("data/datasets/moored.rds")
    
    deployments <- ucorn_20220302$analyses %>% 
      select(-detections) %>% 
      left_join(ucorn_20220302$recorders, by = "unique_id") %>% 
      rename(
        theme = species_group,
        id = unique_id,
        platform_id = platform_no,
        analysis_sampling_rate = analysis_sampling_rate_hz,
        qc_data = qc_processing,
        deployment_type = stationary_or_mobile
      ) %>% 
      mutate(
        platform_type = case_when(
          platform_type == "bottom-mounted" ~ "mooring",
          TRUE ~ NA_character_
        ),
        platform_type = factor(platform_type, levels = levels(moored$deployments$platform_type)),
        duty_cycle_seconds = NA_character_,
        analysis_start_date = as_date(monitoring_start_datetime),
        analysis_end_date = as_date(monitoring_end_datetime),
        analyzed = TRUE,
        submission_date = as_date(submission_date),
        channel = as.character(channel)
      ) %>% 
      select(-c(detection_software_name, detection_software_version, min_analysis_frequency_range_hz, max_analysis_frequency_range_hz, recording_duration_seconds, recording_interval_seconds, sample_bits)) %>% 
      st_as_sf(coords = c("longitude", "latitude"), remove = FALSE)
    stopifnot(
      compare_df_cols_same(moored$deployments, deployments),
      identical(sort(names(moored$deployments)), sort(names(deployments)))
    )
    
    detections <- ucorn_20220302$analyses %>% 
      select(theme = species_group, id = unique_id, detections) %>% 
      unnest(detections) %>% 
      mutate(
        species = NA_character_,
        presence = case_when(
          acoustic_presence == "D" ~ "y",
          acoustic_presence == "P" ~ "m",
          acoustic_presence == "N" ~ "n",
          acoustic_presence == "M" ~ "na",
          TRUE ~ NA_character_
        ),
        presence = factor(presence, levels = levels(moored$detections$presence)),
        locations = map(theme, ~ NULL)
      ) %>% 
      select(-acoustic_presence, -detections)
    stopifnot(
      compare_df_cols_same(moored$detections, detections),
      identical(sort(names(moored$detections)), sort(names(detections)))
    )
    
    filename <- "data/datasets/ucorn_20220302.rds"
    list(
      deployments = deployments,
      detections = detections
    ) %>% 
      write_rds(filename)
    filename
  }, format = "file"),

  # NEFSC 20220816 Deployments ----------------------------------------------
  tar_target(nefsc_20220816_metadata_file, "data/nefsc/20220816-deployments/2022-07_Current_Recorders_forRWSC_edit.csv", format = "file"),
  tar_target(nefsc_20220816_metadata, read_csv(nefsc_20220816_metadata_file, show_col_types = FALSE)),
  tar_target(nefsc_20220816_deployments, {
    nefsc_20220816_metadata %>% 
      janitor::clean_names() %>%
      transmute(
        id = str_replace_all(project_name, " ", "_"),
        project = project_name,
        site_id = site,
        latitude = latitude_ddg_deployment,
        longitude = longitude_ddg_deployment,
        monitoring_start_datetime = mdy_hm(deploy_datetime_gmt),
        platform_type = "mooring",
        sampling_rate_hz = sample_rate_khz * 1e3,
        instrument_type,
        data_poc_name = poc_name,
        data_poc_affiliation = poc_organization,
        data_poc_email = poc_email,
        deployment_type = "stationary",
        soundfiles_timezone = "GMT",
        analyzed = FALSE
      ) %>% 
      filter(!is.na(monitoring_start_datetime)) %>% 
      st_as_sf(coords = c("longitude", "latitude"))
  }),
  tar_target(nefsc_20220816_deployments_rds, {
    filename <- "data/datasets/nefsc_20220816_deployments.rds"
    nefsc_20220816_deployments %>%
      write_rds(filename)
    filename
  }, format = "file")
)