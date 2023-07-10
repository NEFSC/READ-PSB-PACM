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
  tar_target(external_db_tables, read_rds(external_db_tables_file)),
  tar_target(external_submission_groups, {
    tibble(
      id = setdiff(list.dirs(external_dir, recursive = FALSE, full.names = FALSE), "_queue")
    ) %>% 
      group_by(id) %>% 
      tar_group()
  }, iteration = "group"),
  tar_target(external_submission_branches, {
      x <- load_external_submission(
        id = external_submission_groups$id, 
        root_dir = external_dir, 
        db_tables = external_db_tables
      )
      tibble(
        id = external_submission_groups$id,
        metadata = list(x$metadata),
        detectiondata = list(x$detectiondata)
      )
    },
    pattern = map(external_submission_groups)
  ),
  tar_target(external_submissions_merge, external_submission_branches, iteration = "vector"),
  tar_target(external_submissions, {
    rules <- load_external_rules()$detectiondata
    codes <- load_codes(external_db_tables)
    codes[["UNIQUE_ID"]] <- unique(external_metadata$UNIQUE_ID)
    external_submissions_merge %>% 
      rowwise() %>% 
      mutate(
        detectiondata = list({
          print(detectiondata)
          out <- tibble()
          if (nrow(detectiondata) > 0) {
            out <- detectiondata %>%
              rowwise() %>%
              mutate(
                validation = list({
                  validate_data(joined, rules, codes)
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
  tar_target(themes_species, {
    tribble(
      ~theme, ~species_code,
      "narw", "RIWH",
      "blue", "BLWH",
      "humpback", "HUWH",
      "fin", "FIWH",
      "sei", "SEWH",
      "minke", "MIWH",
      
      "beaked", "GOBW",
      "beaked", "MEME",
      "beaked", "SOBW",
      "beaked", "NBWH",
      
      "sperm", "SPWH",
      "harbor", "HAPO"
    )
  }),
  tar_target(external_analyses, {
    x <- external_detectiondata %>% 
      select(-id, -filename, -row) %>%
      clean_names() %>% 
      nest_by(
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
      ungroup() %>% 
      left_join(themes_species, by = "species_code")
    stopifnot(
      all(count(x, unique_id, species_code)$n == 1),
      all(!is.na(x$theme))
    )
    x
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
    
    external_analyses %>% 
      rowwise() %>% 
      mutate(
        analysis_start_datetime = min(data$analysis_period_start_datetime),
        analysis_start_date = as_date(analysis_start_datetime),
        analysis_end_datetime = max(data$analysis_period_start_datetime),
        analysis_end_date = as_date(analysis_end_datetime)
      ) %>% 
      ungroup() %>% 
      select(theme, unique_id, analysis_sampling_rate_hz, qc_data = qc_processing, call_type_code, detection_method, protocol_reference, analysis_start_date, analysis_end_date) %>% 
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
          TRUE ~ platform_type
        )
      ) %>% 
      select(all_of(names(st_drop_geometry(internal$deployments)))) %>% 
      distinct() %>% 
      st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
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
  tar_target(external_detections, {
    analysis_periods <- external_analyses %>% 
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
          TRUE ~ NA_character_
        ),
        species = case_when(
          species_code == "GOBW" ~ "Cuvier's",
          species_code == "MEME" ~ "Unid. Mesoplodon",
          species_code == "NBWH" ~ "Northern Bottlenose",
          species_code == "SOBW" ~ "Sowerby's",
          TRUE ~ NA_character_
        )
      ) %>% 
      select(-species_code)
  }),
  tar_target(external, {
    stopifnot(
      nrow(external_metadata_errors) == 0,
      nrow(external_detectiondata_errors) == 0
    )
    list(
      deployments = external_deployments,
      detections = external_detections
    )
  })
)