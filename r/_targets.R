library(targets)

# packages
options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "lubridate", "janitor", "glue", "units", "patchwork", "logger", "readxl", "validate"))

# load packages into session
if (interactive()) {
  sapply(tar_option_get("packages"), require, character.only = TRUE)
}

# load all functions
invisible(sapply(list.files("R", pattern = ".R", full.names = TRUE), source))

# load all targets
invisible(sapply(list.files("targets", full.names = TRUE), source))

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
      platform_no_exists =! is.na(platform_no),
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
      sample_bits_exists =! is.na(sample_bits),
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

list(
  tar_target(ref_call_type, {
    c(
      "Upcall",
      "Moan",
      "Gunshot",
      "20Hz Pulse",
      "Song",
      "Social",
      "Song & Social",
      "A/B/AB song",
      "Arch",
      "Frequency modulated upsweep",
      "Narrow band high frequency click",
      "Pulse train"
    )
  }),
  tar_target(ref_qc_processing, {
    c(
      "Real-time",
      "Archival"
    )
  }),
  tar_target(ref_species, {
    read_excel(template_detections_file, sheet = "Species_Codes") %>% 
      clean_names()
  }),
  tar_target(refs, {
    list(
      call_type = ref_call_type,
      qc_processing = ref_qc_processing,
      species = ref_species,
      acoustic_presences = c("D", "P", "N", "M")
    )
  }),
  tar_target(template_metadata_file, "data/templates/PACM_TEMPLATE_METADATA.xlsx", format = "file"),
  tar_target(template_detections_file, "data/templates/PACM_TEMPLATE_DETECTIONDATA.xlsx", format = "file"),
  tar_target(template_gps_file, "data/templates/PACM_TEMPLATE_GPSDATA.xlsx", format = "file"),
  tar_target(nydec_metadata_file, "data/nydec-20211216/NYDEC_METADATA_20211216.xlsx", format = "file"),
  tar_target(nydec_metadata_raw, read_excel(nydec_metadata_file, sheet = 1, col_types = "text")),
  tar_target(nydec_metadata_fixed, {
    nydec_metadata_raw %>%
      mutate(
        across(
          c(
            MONITORING_START_DATETIME,
            MONITORING_END_DATETIME
          ),
          ~ format(ymd(19000101) + days(parse_number(.x) - 2), "%FT%T%z")
        ),
        SUBMISSION_DATE = ymd_hms(str_replace(SUBMISSION_DATE, "T0", "T"))
      )
  }),
  tar_target(nydec_metadata, validate_metadata(nydec_metadata_fixed)),
  tar_target(nydec_detections_file, "data/nydec-20211216/NYDEC_DETECTIONDATA_20211216.xlsx", format = "file"),
  tar_target(nydec_detections_raw, read_excel(nydec_detections_file, sheet = 1, col_types = "text")),
  tar_target(nydec_detections, validate_detections(nydec_detections_raw, unique(nydec_metadata$data$unique_id), refs))
)
