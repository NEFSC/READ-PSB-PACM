tar_option_set(packages = c(
  "tarchetypes",
  "tidyverse",
  "lubridate",
  "janitor",
  "glue",
  "units",
  "patchwork",
  "logger",
  "readxl",
  "validate",
  "sf",
  "dotenv",
  "validate"
))

targets_external <- list(
  tar_target(external_dir, "data/external", format = "file", cue = tar_cue("always")),
  tar_target(external_db_tables_file, file.path(external_dir, "db-tables.rds"), format = "file"),
  tar_target(external_db_tables, {
    x <- read_rds(external_db_tables_file)
    swfsc_bw_species_codes <- c("BWBB", "BWMS", "BWMC", "BW43", "BWC", "NBHF")
    stopifnot(!any(swfsc_bw_species_codes %in% x$species$SPECIES_CODE))
    
    # add beaked species from SWFSC
    x$species <- x$species %>% 
      bind_rows(
        tibble(SPECIES_CODE = swfsc_bw_species_codes)
      )
    x
  }),
  tar_target(external_submission_groups, {
    tibble(
      id = setdiff(list.dirs(external_dir, recursive = FALSE, full.names = FALSE), c("_queue", "_archive"))
    ) %>% 
      group_by(id) %>% 
      tar_group()
  }, iteration = "group", cue = tar_cue("always")),
  tar_target(external_submission_branches, {
      x <- load_external_submission(
        id = external_submission_groups$id, 
        root_dir = external_dir, 
        db_tables = external_db_tables
      )
      tibble(
        id = external_submission_groups$id,
        metadata = list(x$metadata),
        detectiondata = list(x$detectiondata),
        gpsdata = list(x$gpsdata)
      )
    },
    pattern = map(external_submission_groups)
  ),
  tar_target(external_submissions_merge, external_submission_branches, iteration = "vector"),
  tar_target(external_submissions, {
    detectiondata_rules <- load_external_rules()$detectiondata
    gpsdata_rules <- load_external_rules()$gpsdata
    codes <- load_codes(external_db_tables)
    codes[["UNIQUE_ID"]] <- unique(external_metadata$UNIQUE_ID)
    external_submissions_merge %>% 
      rowwise() %>% 
      mutate(
        detectiondata = list({
          out <- tibble()
          if (nrow(detectiondata) > 0) {
            out <- detectiondata %>%
              rowwise() %>%
              mutate(
                validation = list({
                  validate_data(joined, detectiondata_rules, codes)
                }),
                validation_errors = list(extract_validation_errors(validation)),
                n_errors = nrow(validation_errors)
              ) %>% 
              ungroup()
          }
          out
        }),
        gpsdata = list({
          out <- tibble()
          if (nrow(gpsdata) > 0) {
            out <- gpsdata %>%
              rowwise() %>%
              mutate(
                validation = list({
                  validate_data(joined, gpsdata_rules, codes)
                }),
                validation_errors = list(extract_validation_errors(validation)),
                n_errors = nrow(validation_errors)
              ) %>% 
              ungroup()
          }
          out
        })
      )
  }),
  tar_target(external_metadata, {
    external_submissions_merge %>% 
      select(metadata) %>% 
      unnest(metadata) %>% 
      select(id, filename, parsed) %>% 
      unnest(parsed)
  }),
  tar_target(external_metadata_errors, {
    external_submissions %>%
      select(metadata) %>%
      unnest(metadata) %>%
      select(id, filename, validation_errors) %>%
      unnest(validation_errors)
  }),
  tar_target(external_detectiondata, {
    external_submissions %>%
      select(detectiondata) %>%
      unnest(detectiondata) %>%
      select(id, filename, parsed) %>%
      unnest(parsed)
  }),
  tar_target(external_detectiondata_errors, {
    external_submissions %>%
      select(detectiondata) %>%
      unnest(detectiondata) %>%
      select(id, filename, validation_errors) %>%
      unnest(validation_errors)
  }),
  tar_target(external_gpsdata, {
    external_submissions %>%
      select(gpsdata) %>%
      unnest(gpsdata) %>%
      select(id, filename, parsed) %>%
      unnest(parsed)
  }),
  tar_target(external_gpsdata_errors, {
    external_submissions %>%
      select(gpsdata) %>%
      unnest(gpsdata) %>%
      select(id, filename, validation_errors) %>%
      unnest(validation_errors)
  }),
  tar_target(themes_species, {
    tribble(
      ~theme, ~species_code,
      "narw", "RIWH",
      "blue", "BLWH",
      "humpback", "HUWH",
      "fin", "FIWH",
      "sei", "SEWH",
      "minke", "MIWH",
      "gray", "GRWH",
      
      "beaked", "GEBW",
      "beaked", "GOBW",
      "beaked", "BLBW",
      "beaked", "MEME",
      "beaked", "SOBW",
      "beaked", "NBWH",
      "beaked", "BWBB",
      "beaked", "BWMS",
      "beaked", "BWMC",
      "beaked", "BW43",
      "beaked", "BWC",
      "beaked", "UNME",
      
      "kogia", "UNKO",
      
      "nbhf", "NBHF",
      
      "dolphin", "UNDO",
      "risso", "GRAM",
      "pwdo", "PWDO",
      
      "pilot", "PIWH",
      
      "sperm", "SPWH",
      "harbor", "HAPO"
    )
  }),
  tar_target(external_tracks, {
    x <- external_gpsdata %>%
      select(UNIQUE_ID, DATETIME, LATITUDE, LONGITUDE) %>% 
      clean_names() %>% 
      arrange(unique_id, datetime) %>% 
      group_by(unique_id, datetime = floor_date(datetime, "hour")) %>% 
      slice_head(n = 1) %>% 
      ungroup()
      
    sf_points <- x %>% 
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
    
    sf_points %>% 
      group_by(unique_id) %>% 
      summarise(
        start = min(datetime),
        end = max(datetime),
        do_union = FALSE,
        .groups = "drop"
      ) %>% 
      st_cast("LINESTRING")
  }),
  tar_target(external_analyses, {
    x_detections <- external_detectiondata %>% 
      select(-id, -filename, -row) %>%
      clean_names()
    x_calltypes <- x_detections %>% 
      distinct(unique_id, species_code, call_type_code) %>%
      group_by(unique_id, species_code) %>%
      summarise(
        # n = n(),
        call_type_code = str_c(call_type_code, collapse = ", "),
        .groups = "drop"
      )
    x_analyses <- x_detections %>% 
      select(-call_type_code) %>% 
      left_join(x_calltypes, by = c("unique_id", "species_code")) %>% 
      inner_join(themes_species, by = "species_code") %>% 
      nest_by(
        theme,
        unique_id,
        species_code,
        call_type_code,
        detection_method,
        qc_processing,
        protocol_reference,
        detection_software_name,
        detection_software_version,
        min_analysis_frequency_range_hz,
        max_analysis_frequency_range_hz,
        analysis_sampling_rate_hz
      ) %>% 
      ungroup()
    stopifnot(
      all(count(x_analyses, unique_id, species_code)$n == 1),
      all(!is.na(x_analyses$theme))
    )
    x_analyses
  }),
  tar_target(external_deployments, {
    # deployments with no detection results
    # external_metadata %>% 
    #   clean_names() %>% 
    #   anti_join(external_analyses, by = "unique_id") %>%
    #   view()
    
    # detection data with no deployments
    # external_analyses %>% 
    #   anti_join(
    #     external_metadata %>% 
    #       select(-id, -filename, -row) %>%
    #       clean_names(),
    #     by = "unique_id"
    #   )
    
    # compute start/end by theme (not species!)
    x_analyses <- external_analyses %>% 
      # select(theme, unique_id, data) %>% 
      unnest(data) %>% 
      group_by(
        theme, unique_id, 
        analysis_sampling_rate_hz,
        qc_data = qc_processing, 
        call_type_code, 
        detection_method,
        protocol_reference
      ) %>% 
      summarise(
        analysis_start_date = as_date(min(analysis_period_start_datetime)),
        analysis_end_date = as_date(max(analysis_period_start_datetime)),
        .groups = "drop"
      )
    stopifnot(
      x_analyses %>% 
        add_count(theme, unique_id) %>% 
        filter(n > 1) %>% 
        nrow() == 0
    )
    
    x <- x_analyses %>% 
      left_join(
        external_metadata %>% 
          select(-id, -filename, -row) %>%
          clean_names(),
        by = "unique_id"
      ) %>% 
      rename(
        id = unique_id,
        platform_id = platform_no,
        call_type = call_type_code,
        deployment_type = stationary_or_mobile
      ) %>%
      mutate(
        analyzed = TRUE,
        duty_cycle_seconds = NA_character_,
        channel = as.character(channel),
        platform_type = case_when(
          platform_type == "BOTTOM-MOUNTED" ~ "mooring",
          platform_type == "DRIFTING-BUOY" ~ "drifting_buoy",
          platform_type == "SURFACE-BUOY" ~ "buoy",
          TRUE ~ platform_type
        )
      ) %>% 
      select(all_of(names(st_drop_geometry(internal$deployments)))) %>% 
      distinct() 
    
    x_stationary <- x %>%
      filter(deployment_type == "STATIONARY") %>%
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
    x_mobile <- x %>%
      filter(deployment_type == "MOBILE") %>%
      left_join(
        external_tracks,
        by = c("id" = "unique_id")
      ) %>% 
      st_as_sf()
    
    bind_rows(x_stationary, x_mobile)
  }),
  tar_target(external_detections_raw, {
    external_analyses %>% 
      unnest(data) %>% 
      select(
        theme, 
        id = unique_id, 
        species_code, 
        datetime = analysis_period_start_datetime,
        acoustic_presence, 
        presence = acoustic_presence
      ) %>%
      mutate(
        presence = case_when(
          presence == "D" ~ "y",
          presence == "M" ~ "na",
          presence == "N" ~ "n",
          presence == "P" ~ "m"
        )
      )
  }),
  tar_target(external_deployments_types, {
    external_deployments %>% 
      distinct(id, deployment_type)
  }),
  tar_target(external_detections_stationary, {
    ids <- external_deployments_types %>% 
      filter(deployment_type == "STATIONARY") %>% 
      pull(id)
    analysis_periods <- external_analyses %>% 
      filter(unique_id %in% ids) %>% 
      rowwise() %>% 
      mutate(
        start = min(as_date(data$analysis_period_start_datetime)),
        end = max(as_date(data$analysis_period_start_datetime))
      ) %>% 
      select(theme, id = unique_id, start, end, species_code) %>%
      mutate(dates = list(tibble(date = seq.Date(start, end, by = 1)))) %>% 
      select(-start, -end) %>% 
      unnest(dates)
    x <- external_detections_raw %>% 
      filter(id %in% ids) %>% 
      count(theme, id, species_code, date = as_date(datetime), presence) %>% 
      pivot_wider(names_from = "presence", values_from = "n", values_fill = 0) %>% 
      mutate(
        presence = case_when(
          y > 0 ~ "y",
          m > 0 ~ "m",
          n > 0 ~ "n",
          TRUE ~ "na"
        ),
        locations = list(NULL)
      ) %>% 
      select(-y, -m, -n, -na)
    analysis_periods %>% 
      left_join(x, by = c("theme", "id", "date", "species_code")) %>% 
      mutate(
        presence = coalesce(presence, "na"),
        species_code = case_when(
          theme == "beaked" ~ species_code,
          theme == "dolphin" ~ species_code,
          TRUE ~ NA_character_
        ),
        species = case_when(
          species_code == "BLBW" ~ "Blainville's",
          species_code == "GEBW" ~ "Gervais'",
          species_code == "GOBW" ~ "Goose-beaked",
          species_code == "BWBB" ~ "Baird's",
          species_code == "BWMS" ~ "Stejneger's",
          species_code == "BWMC" ~ "Hubb's",
          species_code == "BW43" ~ "Unid. 43 kHz Beaked Whale",
          species_code == "BWC" ~ "Cross Seamount",
          species_code == "MEME" ~ "Gervais'/True's",
          species_code == "UNME" ~ "Unid. Mesoplodon",
          species_code == "NBWH" ~ "Northern Bottlenose",
          species_code == "SOBW" ~ "Sowerby's",
          species_code == "UNDO" ~ "Unid. Dolphin",
          # species_code == "GRAM" ~ "Risso's Dolphin",
          TRUE ~ species_code
        )
      ) %>%
      select(-species_code)
  }),
  tar_target(external_detections_mobile, {
    ids <- external_deployments_types %>% 
      filter(deployment_type == "MOBILE") %>% 
      pull(id)
    
    # create approx functions to linearly interpolate latitude and longitude
    x_tracks <- external_gpsdata %>% 
      clean_names() %>% 
      select(unique_id, datetime, latitude, longitude) %>% 
      nest_by(unique_id) %>% 
      mutate(
        data = list({
          data %>% 
            group_by(datetime) %>% 
            summarise(
              latitude = mean(latitude, na.rm = TRUE),
              longitude = mean(longitude, na.rm = TRUE)
            )
        }),
        approx_lat = list(approxfun(data$datetime, data$latitude, rule = 2)),
        approx_lon = list(approxfun(data$datetime, data$longitude, rule = 2))
      ) %>% 
      select(-data)
    
    # add coordinates for each detection
    x_detections_coord <- external_detections_raw %>% 
      filter(id %in% ids) %>% 
      nest_by(id) %>% 
      left_join(x_tracks, by = c("id" = "unique_id")) %>% 
      mutate(
        data = list({
          data %>% 
            mutate(
              latitude = approx_lat(datetime),
              longitude = approx_lon(datetime)
            )
        })
      ) %>% 
      select(-starts_with("approx_")) %>% 
      unnest(data) %>% 
      ungroup()
    
    x_daily <- x_detections_coord %>%
      nest_by(theme, id, species_code, date = as_date(datetime), .key = "locations") %>% 
      mutate(
        presence = case_when(
          any(locations$presence == "y") ~ "y",
          any(locations$presence == "m") ~ "m",
          any(locations$presence == "n") ~ "n",
          any(locations$presence == "na") ~ "na",
          TRUE ~ "na"
        ),
        locations = list({
          head(locations, 1) %>% 
            mutate(date = as_date(datetime)) %>% 
            filter(presence %in% c("y", "m"))
        }),
        species_code = case_when(
          theme == "beaked" ~ species_code,
          theme == "dolphin" ~ species_code,
          TRUE ~ NA_character_
        ),
        species = case_when(
          species_code == "BLBW" ~ "Blainville's",
          species_code == "GEBW" ~ "Gervais'",
          species_code == "GOBW" ~ "Goose-beaked",
          species_code == "BWBB" ~ "Baird's",
          species_code == "BWMS" ~ "Stejneger's",
          species_code == "BWMC" ~ "Hubb's",
          species_code == "BW43" ~ "Unid. 43 kHz Beaked Whale",
          species_code == "BWC" ~ "Cross Seamount",
          species_code == "MEME" ~ "Gervais'/True's",
          species_code == "UNME" ~ "Unid. Mesoplodon",
          species_code == "NBWH" ~ "Northern Bottlenose",
          species_code == "SOBW" ~ "Sowerby's",
          species_code == "UNDO" ~ "Unid. Dolphin",
          # species_code == "GRAM" ~ "Risso's Dolphin",
          TRUE ~ species_code
        )
      ) %>%
      ungroup() %>% 
      select(-species_code)
    
    # fill missing dates by theme,id with non-detects
    x_deployment_dates <- external_deployments %>% 
      semi_join(x_daily, by = c("theme", "id")) %>% 
      st_drop_geometry() %>% 
      transmute(
        theme, id, 
        start = as_date(monitoring_start_datetime), 
        end = as_date(monitoring_end_datetime)
      ) %>% 
      rowwise() %>% 
      mutate(
        date = list(seq.Date(start, end, by = "day"))
      ) %>% 
      select(-start, -end) %>%
      unnest(date) %>% 
      distinct()
    
    x_daily_nondetect <- x_deployment_dates %>% 
      anti_join(x_daily, by = c("theme", "id", "date")) %>% 
      mutate(
        presence = "n",
        locations = list(NULL),
        species = NA
      )
    
    x <- bind_rows(
      x_daily,
      x_daily_nondetect
    ) %>% 
      arrange(theme, id, date)
    
    # no duplicate dates
    stopifnot(
      x %>% 
        add_count(theme, id, date, species) %>%
        filter(n > 1) %>% 
        nrow() == 0
    )
    x
  }),
  tar_target(external_detections, {
    bind_rows(external_detections_stationary, external_detections_mobile)
  }),
  tar_target(external, {
    stopifnot(
      nrow(external_metadata_errors) == 0,
      nrow(external_detectiondata_errors) == 0,
      nrow(external_gpsdata_errors) == 0
    )
    list(
      deployments = external_deployments,
      detections = external_detections
    )
  })
)