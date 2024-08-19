targets_pacm <- list(
  tar_target(pacm_dir, "data/pacm"),
  tar_target(pacm_themes, {
    platform_types <- c("mooring", "buoy", "drifting_buoy", "slocum", "towed")
    
    all_datasets <- list(
      internal,
      external
    )
    
    deployments_all <- map_df(all_datasets, ~ .x$deployments) %>% 
      mutate(
        deployment_type = tolower(deployment_type),
        call_type = fct_recode(
          call_type,
          "Frequency modulated upsweep" = "FMUS",
          "A/B/AB song, Arch/D call" = "BLMIX",
          "Mixed" = "FWMIX",
          "20Hz pulse" = "FWPLS",
          "Song & Social" = "HWMIX",
          "Pulse Train" = "MWPT",
          "Narrow band high frequency click" = "NBHF",
          "30-80Hz downsweep" = "SWDS",
          "Upcall" = "UPCALL",
          "Dolphin clicks" = "ODCLICK",
        )
      )
    detections_all <- map_df(all_datasets, ~ .x$detections)
    
    # filter: deployments ---------------------------------------------------
    
    exclude_deployments_platform_type <- deployments_all %>% 
      filter(!platform_type %in% platform_types) %>% 
      as_tibble() %>% 
      select(-geometry) %>% 
      distinct(id, platform_type)
    
    if (nrow(exclude_deployments_platform_type) > 0) {
      cat(glue("excluding {nrow(exclude_deployments_platform_type)} deployments with invalid platform_type (platform_type in [{str_c(sort(unique(exclude_deployments_platform_type$platform_type)), collapse = ', ')}])"), "\n")
    }
    
    deployments <- deployments_all %>% 
      anti_join(exclude_deployments_platform_type, by = c("id", "platform_type"))
    
    exclude_detections_no_deployment <- detections_all %>% 
      anti_join(deployments, by = c("theme", "id"))
    
    if (nrow(exclude_detections_no_deployment) > 0) {
      cat(glue("excluding {nrow(exclude_detections_no_deployment)} detections with no deployment (id in [{str_c(sort(unique(exclude_detections_no_deployment$id)), collapse = ', ')}])"), "\n")
    }
    
    detections <- detections_all %>% 
      semi_join(deployments, by  = c("theme", "id"))
    
    stopifnot(nrow(exclude_detections_no_deployment) == (nrow(detections_all) - nrow(detections)))
    
    # fill missing values
    detections_full <- deployments %>% 
      st_drop_geometry() %>% 
      filter(analyzed) %>% 
      select(theme, id, analysis_start_date, analysis_end_date) %>%
      semi_join(detections, by = c("theme", "id")) %>%
      rowwise() %>% 
      mutate(
        dates = list({
          tibble(
            date = seq.Date(analysis_start_date, analysis_end_date, by = 1)
          )
        })
      ) %>% 
      ungroup() %>% 
      select(theme, id, dates) %>% 
      unnest(dates) %>% 
      filter(id == "CORNELL_MD_2013_DEP1_A1") %>% 
      print()
      # anti_join(detections, by = c("theme", "id", "date")) %>% 
    
    
    theme_deployments <- deployments %>% 
      filter(platform_type %in% c("buoy", "mooring")) %>% 
      mutate(
        theme = "deployments",
        across(
          c(detection_method, protocol_reference, call_type, analysis_sampling_rate_hz, analyzed, analysis_start_date, analysis_end_date),
          ~ NA
        ),
        across(
          c(analysis_start_date, analysis_end_date),
          as_date
        )
      ) %>% 
      distinct() %>% 
      # filter(!is.na(monitoring_end_datetime)) %>% 
      rowwise() %>% 
      mutate(
        detections = list({
          x <- tibble()
          if (!is.na(monitoring_end_datetime)) {
            x <- tibble(
              date = seq.Date(as_date(monitoring_start_datetime), as_date(monitoring_end_datetime), 1),
              species = NA_character_,
              presence = "d",
              locations = map(id, ~ NULL)
            )
          }
          x
        })
      )
    theme_deployments_detections <- theme_deployments %>% 
      st_drop_geometry() %>% 
      mutate(theme = "deployments") %>% 
      select(theme, id, detections) %>% 
      unnest(detections)
    
    bind_rows(
      deployments %>% 
        filter(!theme == "deployments"),
      select(theme_deployments, -detections)
    ) %>% 
      nest_by(theme, .key = "deployments") %>% 
      left_join(
        bind_rows(
          detections,
          theme_deployments_detections
        ) %>% 
          nest_by(theme, .key = "detections"),
        by = "theme"
      )
  }),
  tar_target(pacm_export_files, {
    stopifnot(dir.exists(pacm_dir))
    
    x <- pacm_themes %>%
      rowwise() %>%
      mutate(
        files = list({
          theme_dir <- file.path(pacm_dir, theme)
          
          if (!dir.exists(theme_dir)) {
            log_info("creating theme directory: {theme_dir}")
            dir.create(theme_dir)
          }
          
          file_deployments <- file.path(theme_dir, "deployments.json")
          
          if (file.exists(file_deployments)) {
            cat(glue("deleting: {file_deployments}"), "\n")
            unlink(file_deployments)
          }
          deployments %>%
            mutate(
              across(
                c(monitoring_start_datetime, monitoring_end_datetime, analysis_start_date, analysis_end_date, submission_date),
                format_ISO8601
              )
            ) %>%
            write_sf(file_deployments, driver = "GeoJSON", layer_options = "ID_FIELD=id")
          
          file_detections <- file.path(theme_dir, "detections.csv")
          detections %>% 
            relocate(locations, .after = last_col()) %>% 
            mutate(
              locations = map_chr(locations, jsonlite::toJSON, null = "null")
            ) %>%
            write_csv(file_detections, na = "")
          
          tibble(filename = c(file_deployments, file_detections))
        })
      )
    x %>% 
      select(theme, deployments) %>% 
      unnest(deployments) %>% 
      tabyl(deployment_type)
    x %>% 
      select(files) %>% 
      unnest(files) %>% 
      pull(filename)
  }, format = "file")
)