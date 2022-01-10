validate_metadata <- function (raw) {
  {
    parsed <- raw %>%
      clean_names() %>%
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
      unique_id_is_unique = is_unique(unique_id),
      stationary_or_mobile_valid = stationary_or_mobile %vin% tolower(c("Stationary", "Mobile")),
      platform_type_valid = platform_type %vin% tolower(c("Bottom-Mounted", "Surface-buoy",  "Electric-glider", "Wave-glider", "Towed-array", "Linear-array", "Drifting-buoy")),
      unique_id_exists = !is.na(unique_id),
      project_exists = !is.na(project),
      data_poc_name_exists = !is.na(data_poc_name),
      data_poc_affiliation_exists = !is.na(data_poc_affiliation),
      data_poc_email_exists = !is.na(data_poc_email),
      stationary_or_mobile_exists = !is.na(stationary_or_mobile),
      platform_type_exists = !is.na(platform_type),
      # platform_no_exists =! is.na(platform_no),
      site_id_exists =! is.na(site_id),
      instrument_type_exists =! is.na(instrument_type),
      instrument_id_exists =! is.na(instrument_id),
      channel_exists =! is.na(channel),
      monitoring_start_datetime_exists =! is.na(monitoring_start_datetime),
      monitoring_end_datetime_exists =! is.na(monitoring_end_datetime),
      soundfiles_timezone_exists =! is.na(soundfiles_timezone),
      latitude_exists =! is.na(latitude),
      longitude_exists =! is.na(longitude),
      water_depth_meters_exists =! is.na(water_depth_meters),
      recorder_depth_meters_exists =! is.na(recorder_depth_meters),
      sampling_rate_hz_exists =! is.na(sampling_rate_hz),
      recording_duration_seconds_exists =! is.na(recording_duration_seconds),
      recording_interval_seconds_exists =! is.na(recording_interval_seconds),
      # sample_bits_exists =! is.na(sample_bits),
      submitter_name_exists = !is.na(submitter_name),
      submitter_affiliation_exists = !is.na(submitter_affiliation),
      submitter_email_exists = !is.na(submitter_email),
      submission_date_exists = !is.na(submission_date)
    )
    out <- confront(
      parsed,
      rules,
      ref = list()
    )
    
    rejected <- summary(out) %>% 
      filter(fails > 0) %>% 
      pull(name) %>% 
      map(function (x) {
        list(
          rule = x,
          rows = violating(raw, out[x])
        )
      })
    
    for (rule in rejected) {
      log_error("failed: {rule$rule} (n={nrow(rule$rows)})")
    }
    
    list(
      data = satisfying(parsed, out),
      rejected = rejected
    )
  }
}

validate_detections <- function (raw, unique_ids, refs) {
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
    unique_id_exists = !is.na(unique_id),
    unique_id_is_unique = unique_id %vin% unique_ids,
    analysis_period_start_datetime_exists = !is.na(analysis_period_start_datetime),
    analysis_period_end_datetime_exists = !is.na(analysis_period_end_datetime),
    analysis_period_effort_seconds_exists = !is.na(analysis_period_effort_seconds),
    species_exists = !is.na(species),
    acoustic_presence_exists = !is.na(acoustic_presence),
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
  
  rejected <- summary(out) %>% 
    filter(fails > 0) %>% 
    pull(name) %>% 
    map(function (x) {
      list(
        rule = x,
        rows = violating(raw, out[x])
      )
    })
  
  for (rule in rejected) {
    log_error("failed: {rule$rule} (n={nrow(rule$rows)})")
  }
  
  list(
    data = satisfying(parsed, out),
    rejected = rejected
  )
}
