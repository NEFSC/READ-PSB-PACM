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
    metadata <- raw %>%
      clean_names() %>%
      mutate(
        # across(
        #   c(
        #     monitoring_start_datetime,
        #     monitoring_end_datetime,
        #     submission_date
        #   ),
        #   ymd_hms
        # ),
        across(
          c(
            monitoring_start_datetime,
            monitoring_end_datetime
          ),
          ~ ymd(19000101) + days(parse_number(.x) - 2)
        ),
        submission_date = ymd_hms(str_replace(submission_date, "T0", "T")),
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
    
    rule <- validator(
      !is.na(unique_id),
      is_unique(unique_id),
      !is.na(project),
      !is.na(data_poc_name),
      !is.na(data_poc_affiliation),
      !is.na(data_poc_email),
      !is.na(stationary_or_mobile),
      stationary_or_mobile %vin% tolower(c("Stationary", "Mobile")),
      !is.na(platform_type),
      platform_type %vin% tolower(c("Bottom-Mounted", "Surface-buoy",  "Electric-glider", "Wave-glider", "Towed-array", "Linear-array", "Drifting-buoy")),
      !is.na(platform_no),
      !is.na(site_id),
      !is.na(instrument_type),
      !is.na(instrument_id),
      !is.na(channel),
      !is.na(monitoring_start_datetime),
      !is.na(monitoring_end_datetime),
      !is.na(soundfiles_timezone),
      !is.na(latitude),
      !is.na(longitude),
      !is.na(water_depth_meters),
      !is.na(recorder_depth_meters),
      !is.na(sampling_rate_hz),
      !is.na(recording_duration_seconds),
      !is.na(recording_interval_seconds),
      !is.na(sample_bits),
      !is.na(submitter_name),
      !is.na(submitter_affiliation),
      !is.na(submitter_email),
      !is.na(submission_date)
    )
    out <- confront(
      metadata,
      rule,
      ref = list(
      )
    )
    stopifnot(all(summary(out)["fails"] == 0))
    
    list(
      data = satisfying(metadata, out),
      rejected = violating(raw, out)
    )
    metadata
  }
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
  tar_target(ref_qc_processing, c("Real-time", "Archival")),
  tar_target(template_metadata_file, "data/templates/PACM_TEMPLATE_METADATA.xlsx", format = "file"),
  tar_target(template_detections_file, "data/templates/PACM_TEMPLATE_DETECTIONDATA.xlsx", format = "file"),
  tar_target(ref_species, {
    read_excel(template_detections_file, sheet = "Species_Codes") %>% 
      clean_names()
  }),
  tar_target(template_gps_file, "data/templates/PACM_TEMPLATE_GPSDATA.xlsx", format = "file"),
  tar_target(nydec_metadata_file, "data/nydec-20211216/NYDEC_METADATA_20211216.xlsx", format = "file"),
  tar_target(nydec_metadata_raw, read_excel(nydec_metadata_file, sheet = 1, col_types = "text")),
  tar_target(nydec_metadata, validate_metadata(nydec_metadata_raw)),
  tar_target(nydec_detections_file, "data/nydec-20211216/NYDEC_DETECTIONDATA_20211216.xlsx", format = "file"),
  tar_target(nydec_detections_raw, read_excel(nydec_detections_file, sheet = 1, col_types = "text")),
  tar_target(nydec_detections, {
    detections <- nydec_detections_raw %>%
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
    
    rule <- validator(
      !is.na(unique_id),
      unique_id %vin% unique_ids,
      !is.na(analysis_period_start_datetime),
      !is.na(analysis_period_end_datetime),
      !is.na(analysis_period_effort_seconds),
      !is.na(species),
      species %vin% species_codes,
      !is.na(acoustic_presence),
      acoustic_presence %in% c("D", "P", "N", "M"),
      call_type %in% call_types,
      qc_processing %in% qc_processings
    )
    out <- confront(
      detections, 
      rule, 
      ref = list(
        unique_ids = unique(nydec_metadata_raw$UNIQUE_ID),
        species_codes = ref_species$species_code,
        call_types = ref_call_type,
        qc_processings = ref_qc_processing
      )
    )
    summary(out)
    
    list(
      data = satisfying(detections, out),
      rejected = violating(nydec_detections_raw, out)
    )
  })
)