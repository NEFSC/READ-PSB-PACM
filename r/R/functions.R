

# datasets -----------------------------------------------------------------

noop <- function (x) { x }

join_metadata_detections <- function(metadata, detections, themes) {
  stopifnot(
    all(
      detections %>%
        distinct(unique_id, analysis_sampling_rate_hz, call_type, detection_method, protocol_reference, qc_processing, call_type) %>%
        add_count(unique_id) %>%
        pull(n) == 1
    )
  )

  detections_metadata <- detections %>%
    distinct(
      unique_id,
      analysis_sampling_rate_hz,
      call_type,
      detection_method,
      protocol_reference,
      qc_processing
    )

  detections_analysis_period <- detections %>%
    group_by(unique_id) %>%
    summarise(
      analysis_start_date = as_date(min(analysis_period_start_datetime)),
      analysis_end_date = as_date(max(analysis_period_start_datetime)),
      .groups = "drop"
    ) %>%
    mutate(
      analyzed = TRUE
    )

  deployments_metadata <- metadata %>%
    inner_join(detections_analysis_period, by = "unique_id") %>%
    left_join(detections_metadata, by = "unique_id")

  # only keep deployments with detection data
  stopifnot(nrow(deployments_metadata) == nrow(detections_analysis_period))

  # fill: missing detections ------------------------------------------------
  # presence = na for any date missing within the analysis period

  # dates over analysis period of each deployment
  deployments_dates <- deployments_metadata %>%
    transmute(
      unique_id,
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
  detections_fill <- deployments_dates %>%
    select(unique_id, date) %>%
    full_join(
      detections %>%
        mutate(date = as_date(analysis_period_start_datetime)),
      by = c("unique_id", "date")
    ) %>%
    select(unique_id, date, species, acoustic_presence)
  stopifnot(all(!is.na(detections$acoustic_presence)))


  # qaqc: detections --------------------------------------------------------

  # no detections are outside the deployment analysis period
  stopifnot(
    detections %>%
      mutate(date = as_date(analysis_period_start_datetime)) %>%
      anti_join(deployments_dates, by = c("unique_id", "date")) %>%
      nrow() == 0
  )

  # deployment monitoring days with no detection data (filled with presence = na)
  stopifnot(
    deployments_dates %>%
      anti_join(
        detections %>%
          mutate(date = as_date(analysis_period_start_datetime)),
        by = c("unique_id", "date")
      ) %>%
      distinct(unique_id, start, end, date) %>%
      select(unique_id, analysis_start_date = start, analysis_end_date = end, date) %>%
      arrange(unique_id, analysis_start_date, date) %>%
      nrow() == 0
  )

  # none of the deployments are all NA
  stopifnot(
    detections_fill %>%
      group_by(unique_id) %>%
      summarise(n_total = n(), n_missing = sum(acoustic_presence == "M")) %>%
      filter(n_total == n_missing) %>%
      nrow() == 0
  )

  # deployments geom --------------------------------------------------------

  deployments_sf <- deployments_metadata %>%
    distinct(unique_id, latitude, longitude) %>%
    sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
  #
  # mapview::mapview(deployments_sf, legend = FALSE)
  #
  deployments <- deployments_sf %>%
    left_join(deployments_metadata, by = "unique_id") %>%
    mutate(deployment_type = "stationary") %>%
    relocate(deployment_type, geometry, .after = last_col())


  # themes ------------------------------------------------------------------
  # MERGE SPECIES_CODE WITH THEMES
  # [theme, unique_id]

  stopifnot(all(unique(detections$species) %in% themes$species_code))
  deployments_themes <- distinct(detections, unique_id, species) %>%
    left_join(
      themes,
      by = c("species" = "species_code")
    ) %>%
    nest_by(theme, unique_id, .key = "species")


  # qaqc --------------------------------------------------------------------

  # qaqc_dataset(deployments, detections)

  list(
    deployments = deployments,
    detections = detections_fill,
    themes = deployments_themes
  )
}

aggregate_detections <- function(detections, monitoring_start_datetime,
                                 monitoring_end_datetime, platform_type) {
  stopifnot(
    !is.na(monitoring_start_datetime),
    !is.na(monitoring_end_datetime),
    monitoring_end_datetime >= monitoring_start_datetime,
    !is.na(platform_type)
  )
  
  first_detection_date <- as_date(min(detections$analysis_period_start_datetime))
  last_detection_date <- as_date(max(detections$analysis_period_start_datetime))
  start_date <- min(first_detection_date, as_date(monitoring_start_datetime))
  end_date <- max(last_detection_date, as_date(monitoring_end_datetime))
  if (end_date > start_date & last_detection_date < as_date(monitoring_end_datetime) & end_date != as_date(monitoring_end_datetime - minutes(1))) {
    end_date <- end_date - days(1)
  }
  dates <- seq.Date(start_date, end_date, by = "day")
  
  x_date <- detections %>% 
    mutate(date = as_date(analysis_period_start_datetime))
  
  stopifnot(
    all(x_date$date >= start_date),
    all(x_date$date <= end_date)
  )
  
  x <- x_date %>% 
    nest_by(species, date, .key = "detections") %>% 
    ungroup() %>% 
    complete(date = dates, species, fill = list(detections = list(tibble()))) %>% 
    rowwise() 
  if (platform_type == "towed-array") {
    x <- x %>% 
      mutate(
        acoustic_presence = case_when(
          nrow(detections) == 0 ~ "N",
          sum(detections$acoustic_presence == "D") > 0 ~ "D",
          sum(detections$acoustic_presence == "P") > 0 ~ "P",
          sum(detections$acoustic_presence == "M") > 0 ~ "M",
          TRUE ~ NA_character_
        )
      )
  } else {
    x <- x %>% 
      mutate(
        acoustic_presence = case_when(
          nrow(detections) == 0 ~ "M",
          sum(detections$acoustic_presence == "D") > 0 ~ "D",
          sum(detections$acoustic_presence == "P") > 0 ~ "P",
          sum(detections$acoustic_presence == "N") > 0 ~ "N",
          sum(detections$acoustic_presence == "M") > 0 ~ "M",
          TRUE ~ NA_character_
        )
      )
  }
  ungroup(x)
}

create_analyses <- function (metadata, detections, refs) {
  refs[["species_group"]] %>% 
    inner_join(detections, by = "species") %>% 
    nest_by(
      species_group,
      unique_id,
      call_type,
      detection_method,
      qc_processing,
      protocol_reference,
      detection_software_name,
      detection_software_version,
      min_analysis_frequency_range_hz,
      max_analysis_frequency_range_hz,
      analysis_sampling_rate_hz,
      .key = "detections"
    ) %>% 
    ungroup() %>% 
    left_join(
      metadata %>% 
        select(unique_id, monitoring_start_datetime, monitoring_end_datetime, platform_type),
      by = "unique_id"
    ) %>% 
    mutate(
      detections = pmap(list(detections, monitoring_start_datetime, monitoring_end_datetime, platform_type), aggregate_detections)
    ) %>% 
    select(-c(monitoring_start_datetime, monitoring_end_datetime, platform_type))
}

read_metadata <- function (file, clean = noop) {
  raw <- read_csv(file, col_types = cols(.default = col_character()), na = c("NA", ""))
  cleaned <- clean(raw)
  validate_metadata(cleaned)
}

read_detections <- function(files) {
  tibble(
    FILE = files,
    DATA = map(FILE, function (x) {
      log_info("loading: detections ({basename(x)})")
      read_csv(x, col_types = cols(.default = col_character()), na = c("NA", ""))%>% 
        select(-starts_with("..."))
    })
  ) %>% 
    mutate(FILE = basename(FILE)) %>% 
    unnest(DATA)
}

read_dataset <- function(files, clean = NULL, refs) {
  if (is.null(clean)) {
    clean <- list(
      metadata = function (x) {x},
      detections = function (x) {x}
    )
  }
  if (!"metadata" %in% names(clean)) {
    clean[["metadata"]] <- function (x) {x}
  }
  if (!"detections" %in% names(clean)) {
    clean[["detections"]] <- function (x) {x}
  }
  if (!"tracks" %in% names(clean)) {
    clean[["tracks"]] <- function (x) {x}
  }
  
  log_info("loading: metadata ({basename(files[['metadata']])})")
  # metadata_raw <- read_csv(files[["metadata"]], col_types = cols(.default = col_character()), na = c("NA", ""))
  # metadata_clean <- clean[["metadata"]](metadata_raw)
  # metadata <- validate_metadata(metadata_clean)
  metadata <- read_metadata(files[["metadata"]], clean[["metadata"]])
  log_info("validation: metadata (passed={nrow(metadata$data)}, failed={nrow(metadata$rejected)})")
  
  detections_raw <- read_detections(files[["detections"]])
  detections_clean <- clean[["detections"]](detections_raw)
  detections <- validate_detections(detections_clean, metadata$data, refs)
  log_info("validation: detections (passed={nrow(detections$data)}, failed={nrow(detections$rejected)})")
  
  if ("tracks" %in% names(files)) {
    log_info("loading: tracks ({basename(files[['tracks']])})")
    tracks_raw <- read_csv(files[["tracks"]], col_types = cols(.default = col_character()), na = c("NA", ""))
    tracks_clean <- clean[["tracks"]](tracks_raw)
    tracks <- validate_track(tracks_clean, metadata$data, refs)
    log_info("validation: tracks (passed={nrow(tracks$data)}, failed={nrow(tracks$rejected)})")
  } else {
    tracks <- NULL
  }
  
  list(
    metadata = metadata,
    detections = detections,
    tracks = tracks
  )
}

aggregate_tracks <- function(raw, metadata) {
  raw %>% 
    left_join(
      metadata %>% 
        select(
          unique_id, 
          platform_type,
          monitoring_start_datetime,
          monitoring_end_datetime
        ),
      by = "unique_id"
    ) %>% 
    filter(
      datetime >= monitoring_start_datetime,
      datetime <= monitoring_end_datetime
    ) %>% 
    group_by(unique_id, datetime = floor_date(datetime, unit = "hour")) %>% 
    summarise(across(c(latitude, longitude), mean), .groups = "drop") %>% 
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>% 
    group_by(unique_id) %>% 
    summarise(
      start = min(datetime),
      end = max(datetime),
      do_union = FALSE
    ) %>% 
    st_cast("MULTILINESTRING")
}

add_detection_positions <- function(detections, metadata, tracks) {
  x <- detections %>% 
    left_join(
      metadata %>% 
        select(unique_id, stationary_or_mobile),
      by = "unique_id"
    )
  
  x_stationary <- x %>% 
    filter(stationary_or_mobile == "stationary") %>% 
    select(-stationary_or_mobile)
  x_mobile <- x %>% 
    filter(stationary_or_mobile == "mobile") %>% 
    select(-stationary_or_mobile) %>% 
    nest_by(unique_id, .key = "detections") %>% 
    left_join(
      tracks %>% 
        nest_by(unique_id, .key = "track"),
      by = "unique_id"
    ) %>%
    mutate(
      latitude_fun = list(approxfun(track$datetime, y = track$latitude, rule = 1)),
      longitude_fun = list(approxfun(track$datetime, y = track$longitude, rule = 1)),
      detections_position = list(
        detections %>% 
        mutate(
          latitude = latitude_fun(analysis_period_start_datetime),
          longitude = longitude_fun(analysis_period_start_datetime)
        )
      )
    )
  bind_rows(
    x_stationary %>% 
      mutate(latitude = NA_real_, longitude = NA_real_),
    x_mobile %>% 
      select(unique_id, detections_position) %>% 
      unnest(detections_position)
  )
}

process_dataset <- function(dataset, refs) {
  stopifnot(nrow(dataset$metadata$rejected) == 0)
  stopifnot(nrow(dataset$detections$rejected) == 0)
  
  metadata <- dataset$metadata$data
  detections <- dataset$detections$data
  
  if (!is.null(dataset$tracks)) {
    tracks <- dataset$tracks$data %>% 
      group_by(unique_id, datetime) %>% 
      summarise(across(c(latitude, longitude), mean), .groups = "drop")
    detections <- add_detection_positions(detections, metadata, tracks)
    
    stopifnot(nrow(dataset$tracks$rejected) == 0)
    tracks_hourly <- aggregate_tracks(dataset$tracks$data, metadata)
  } else {
    tracks_hourly <- NULL
  }
  
  analyses <- create_analyses(metadata, detections, refs)
  
  list(
    recorders = metadata,
    detections = detections,
    analyses = analyses,
    tracks = tracks_hourly
  )
}

plot_analyses <- function (x) {
  x %>% 
    select(species_group, unique_id, detections) %>% 
    unnest(detections) %>% 
    mutate(acoustic_presence = factor(acoustic_presence, levels = c("D", "N", "P", "M"))) %>% 
    ggplot(aes(date, unique_id)) +
    geom_jitter(aes(color = acoustic_presence), width = 0) +
    scale_color_brewer("Presence", type = "qual", palette = 6, drop = FALSE) +
    facet_wrap(vars(species_group, species), scales = "free_x", labeller = label_both)
}

# validate ---------------------------------------------------------------

validate_metadata <- function (raw) {
  raw <- raw %>% mutate(
    ROW = row_number()
  ) %>% 
    relocate(ROW)

  parsed <- raw %>%
    clean_names() %>%
    select(-row, -starts_with("x")) %>% 
    mutate(
      across(
        c(
          monitoring_start_datetime,
          monitoring_end_datetime,
          submission_date
        ),
        ymd_hms
      ),
      across(
        c(
          channel,
          latitude,
          longitude,
          water_depth_meters,
          recorder_depth_meters,
          sampling_rate_hz,
          recording_duration_seconds,
          recording_interval_seconds,
          sample_bits
        ),
        parse_number
      ),
      across(
        c(stationary_or_mobile, platform_type),
        tolower
      )
    )
  
  rules <- validator(
    unique_id_not_unique = is_unique(unique_id),
    stationary_or_mobile_valid = stationary_or_mobile %vin% tolower(c("Stationary", "Mobile")),
    platform_type_valid = platform_type %vin% tolower(c("Bottom-Mounted", "Surface-buoy",  "Electric-glider", "Wave-glider", "Towed-array", "Linear-array", "Drifting-buoy")),
    unique_id_missing = !is.na(unique_id),
    project_missing = !is.na(project),
    data_poc_name_missing = !is.na(data_poc_name),
    data_poc_affiliation_missing = !is.na(data_poc_affiliation),
    data_poc_email_missing = !is.na(data_poc_email),
    stationary_or_mobile_missing = !is.na(stationary_or_mobile),
    platform_type_missing = !is.na(platform_type),
    # platform_no_missing = !is.na(platform_no),
    site_id_missing = !is.na(site_id),
    instrument_type_missing = !is.na(instrument_type),
    # instrument_id_missing = !is.na(instrument_id),
    # channel_missing = !is.na(channel),
    monitoring_start_datetime_missing = !is.na(monitoring_start_datetime),
    monitoring_end_datetime_missing = !is.na(monitoring_end_datetime),
    soundfiles_timezone_missing = !is.na(soundfiles_timezone),
    latitude_missing = if (stationary_or_mobile == "stationary") !is.na(latitude),
    longitude_missing = if (stationary_or_mobile == "stationary") !is.na(longitude),
    # water_depth_meters_missing = !is.na(water_depth_meters),
    # recorder_depth_meters_missing = !is.na(recorder_depth_meters),
    sampling_rate_hz_missing = !is.na(sampling_rate_hz),
    recording_duration_seconds_missing = !is.na(recording_duration_seconds),
    recording_interval_seconds_missing = !is.na(recording_interval_seconds),
    # sample_bits_missing = !is.na(sample_bits),
    submitter_name_missing = !is.na(submitter_name),
    submitter_affiliation_missing = !is.na(submitter_affiliation),
    submitter_email_missing = !is.na(submitter_email),
    submission_date_missing = !is.na(submission_date)
  )
  out <- confront(
    parsed,
    rules,
    ref = list()
  )
  
  rejected_rules <- summary(out) %>% 
    filter(fails > 0) %>% 
    pull(name) %>% 
    map_df(function (x) {
      tibble(
        RULE = x,
        ROW = violating(raw, out[x]) %>% 
          pull(ROW)
      )
    })
  
  rejected_rows <- tibble()
  if (nrow(rejected_rules) > 0) {
    rejected_rows <- rejected_rules %>% 
      group_by(ROW) %>% 
      summarise(RULES = str_c(RULE, collapse = ",")) %>% 
      left_join(raw, by = "ROW")
    
    rejected_rules_count <- count(rejected_rules, RULE)
    
    # for (i in 1:nrow(rejected_rules_count)) {
    #   log_error("validation failed (metadata): {rejected_rules_count[i, 'RULE']} (n={rejected_rules_count[i, 'n']})")
    # }
  }
  
  list(
    data = satisfying(parsed, out, include_missing = TRUE),
    rejected = rejected_rows
  )
}

validate_detections <- function (raw, metadata, refs) {
  stopifnot(nrow(metadata) > 0)
  
  unique_ids <- metadata$unique_id
  
  raw <- raw %>% mutate(
    ROW = row_number()
  ) %>% 
    relocate(ROW)
  
  parsed <- raw %>%
    clean_names() %>%
    mutate(
      across(
        c(
          analysis_period_start_datetime, 
          analysis_period_end_datetime
        ),
        ymd_hms
      ),
      across(
        c(
          analysis_period_effort_seconds, 
          n_validated_detections, 
          min_analysis_frequency_range_hz, 
          max_analysis_frequency_range_hz,
          analysis_sampling_rate_hz
        ),
        parse_number
      )
    )
  
  rules <- validator(
    unique_id_missing = !is.na(unique_id),
    unique_id_not_in_metadata = unique_id %vin% unique_ids,
    analysis_period_start_datetime_missing = !is.na(analysis_period_start_datetime),
    analysis_period_end_datetime_missing = !is.na(analysis_period_end_datetime),
    # analysis_period_effort_seconds_missing = !is.na(analysis_period_effort_seconds),
    species_missing = !is.na(species),
    acoustic_presence_missing = !is.na(acoustic_presence),
    analysis_sampling_rate_hz_missing = !is.na(analysis_sampling_rate_hz),
    species_valid = species %vin% species_codes,
    acoustic_presence_valid = acoustic_presence %in% acoustic_presences,
    call_type_valid = call_type %in% call_types,
    qc_processing_valid = qc_processing %in% qc_processings
  )
  
  out <- confront(
    parsed, 
    rules, 
    ref = list(
      unique_ids = unique_ids,
      species_codes = refs$species$species_code,
      call_types = refs$call_type,
      qc_processings = refs$qc_processing,
      acoustic_presences = refs$acoustic_presences
    )
  )
  
  rejected_rules <- summary(out) %>% 
    filter(fails > 0) %>% 
    pull(name) %>% 
    map_df(function (x) {
      tibble(
        RULE = x,
        ROW = violating(raw, out[x]) %>% 
          pull(ROW)
      )
    })
  
  rejected_rows <- tibble()
  if (nrow(rejected_rules) > 0) {
    rejected_rows <- rejected_rules %>% 
      group_by(ROW) %>% 
      summarise(RULES = str_c(RULE, collapse = ",")) %>% 
      left_join(raw, by = "ROW")
    
    rejected_rules_count <- count(rejected_rules, RULE)
    
    # for (i in 1:nrow(rejected_rules_count)) {
    #   log_error("validation failed (metadata): {rejected_rules_count[i, 'RULE']} (n={rejected_rules_count[i, 'n']})")
    # }
  }
  
  list(
    data = satisfying(parsed, out, include_missing = TRUE),
    rejected = rejected_rows
  )
}

validate_track <- function (raw, metadata, refs) {
  stopifnot(nrow(metadata) > 0)
  
  unique_ids <- metadata$unique_id
  
  raw <- raw %>% mutate(
    ROW = row_number()
  ) %>% 
    relocate(ROW)
  
  parsed <- raw %>%
    clean_names() %>%
    mutate(
      across(datetime, ymd_hms),
      across(c(latitude, longitude), parse_number)
    )
  
  rules <- validator(
    unique_id_missing = !is.na(unique_id),
    unique_id_not_in_metadata = unique_id %vin% unique_ids,
    datetime_missing = !is.na(datetime),
    latitude_missing = !is.na(latitude),
    longitude_missing = !is.na(longitude)
  )
  
  out <- confront(
    parsed, 
    rules
  )
  
  rejected_rules <- summary(out) %>% 
    filter(fails > 0) %>% 
    pull(name) %>% 
    map_df(function (x) {
      tibble(
        RULE = x,
        ROW = violating(raw, out[x]) %>% 
          pull(ROW)
      )
    })
  
  rejected_rows <- tibble()
  if (nrow(rejected_rules) > 0) {
    rejected_rows <- rejected_rules %>% 
      group_by(ROW) %>% 
      summarise(RULES = str_c(RULE, collapse = ",")) %>% 
      left_join(raw, by = "ROW")
    
    rejected_rules_count <- count(rejected_rules, RULE)
    
    # for (i in 1:nrow(rejected_rules_count)) {
    #   log_error("validation failed (metadata): {rejected_rules_count[i, 'RULE']} (n={rejected_rules_count[i, 'n']})")
    # }
  }
  
  list(
    data = satisfying(parsed, out, include_missing = TRUE),
    rejected = rejected_rows
  )
}