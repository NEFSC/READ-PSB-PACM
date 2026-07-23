# CVOWC_20260105 - legacy PACM_20240820 submission, converted to PARS.
#
# raw/ is the immutable submitted data. The munging below is unchanged from
# the pre-migration clean.R; only the final write is replaced by the shared
# legacy -> PARS conversion, which writes PARS-format files to clean/.

library(tidyverse)
library(janitor)
library(readxl)
library(glue)
source("R/functions.R")


dir <- "data-raw/pars/CVOWC_20260105"

analyses <- read_csv(file.path(dir, "raw", "CVOW-C_20260105_analyses.csv"), col_types = cols(.default = col_character())) |> 
  mutate(
    analysis_organization_code = organization_code,
    deployment_organization_code = organization_code,
    detector_codes = case_when(
      detector_codes == "CHORUS BioSound" ~ "CHORUS_BIOSOUND",
      TRUE ~ detector_codes
    ),
    analysis_sound_source_codes = "BLWH,FIWH,HUWH,MIWH,SEWH,RIWH,BODO,UNDO,UNWH"
  ) |> 
  select(-organization_code)
devices <- read_csv(file.path(dir, "raw", "CVOW-C_20260105_devices.csv"), col_types = cols(.default = col_character()))
detections <- read_csv(file.path(dir, "raw", "CVOW-C_20260105_detections.csv"), col_types = cols(.default = col_character())) |> 
  mutate(
    analysis_organization_code = organization_code,
    deployment_organization_code = organization_code,
    detection_result_code = toupper(detection_result_code)
  ) |> 
  select(-organization_code)
deployments <- read_csv(file.path(dir, "raw", "CVOW-C_20260105_deployments.csv"), col_types = cols(.default = col_character())) |> 
  mutate(
    deployment_json = NA_character_,
    recovery_json = NA_character_,
    parent_deployment_code = NA_character_,
    recovery_burn_datetime = NA_character_
  )
recordings <- read_csv(file.path(dir, "raw", "CVOW-C_20260105_recordings.csv"), col_types = cols(.default = col_character()))
sites <- read_csv(file.path(dir, "raw", "CVOW-C_20260105_sites.csv"), col_types = cols(.default = col_character()))


# export for makara validation -------------------------------------------

# dir.create(file.path(dir, "clean-makara"), showWarnings = FALSE)
# write_csv(analyses, file.path(dir, "clean-makara", "analyses.csv"), na = "")
# write_csv(devices, file.path(dir, "clean-makara", "devices.csv"), na = "")
# write_csv(detections, file.path(dir, "clean-makara", "detections.csv"), na = "")
# write_csv(deployments, file.path(dir, "clean-makara", "deployments.csv"), na = "")
# write_csv(recordings, file.path(dir, "clean-makara", "recordings.csv"), na = "")
# write_csv(sites, file.path(dir, "clean-makara", "sites.csv"), na = "")


# export for pacm --------------------------------------------------------

deployments_recordings <- recordings |> 
  nest(recordings = -c(organization_code, deployment_code, recording_sample_rate_khz, recording_bit_depth, recording_device_depth_m)) |> 
  mutate(
    recording_device_codes = map_chr(recordings, ~ str_c(unique(.x$recording_device_codes), collapse = ",")),
    recording_dates = map(recordings, function (x) {
      x |> 
        mutate(start_date = as_date(ymd_hm(recording_start_datetime)), end_date = as_date(ymd_hm(recording_end_datetime))) |>
        mutate(
          dates = map2(start_date, end_date, ~ seq.Date(.x, .y, by = "1 day"))
        ) |> 
        select(date = dates) |> 
        unnest(date) |> 
        distinct() |> 
        pull(date)
    })
  )
stopifnot(!anyDuplicated(deployments_recordings$deployment_code))

pacm_sites <- sites |> 
  mutate(
    site_id = glue("{organization_code}:{site_code}")
  )

# deployments w/o recordings
deployments |> 
  anti_join(
    deployments_recordings,
    by = c("organization_code", "deployment_code")
  )

pacm_metadata <- deployments |> 
  # exclude deployments missing recordings (n=5)
  inner_join(
    deployments_recordings,
    by = c("organization_code", "deployment_code")
  ) |> 
  transmute(
    UNIQUE_ID = deployment_code,
    PROJECT = project_code,
    DATA_POC_NAME = NA_character_,
    DATA_POC_AFFILIATION = organization_code,
    DATA_POC_EMAIL = NA_character_,
    STATIONARY_OR_MOBILE = "STATIONARY",
    PLATFORM_TYPE = deployment_platform_type_code,
    PLATFORM_NO = NA_character_,
    SITE_ID = site_code,
    INSTRUMENT_TYPE = unique(devices$device_type_code),
    CHANNEL = NA_character_,
    SOUNDFILES_TIMEZONE = NA_character_,
    LATITUDE = deployment_latitude,
    LONGITUDE = deployment_longitude,
    WATER_DEPTH_METERS = deployment_water_depth_m,
    RECORDER_DEPTH_METERS = recording_device_depth_m,
    SAMPLING_RATE_HZ = as.numeric(recording_sample_rate_khz) * 1000,
    SAMPLE_BITS = recording_bit_depth,
    SUBMITTER_NAME = NA_character_,
    SUBMITTER_AFFILIATION = NA_character_,
    SUBMITTER_EMAIL = NA_character_,
    SUBMISSION_DATE = NA_character_,
    INSTRUMENT_ID = recording_device_codes,
    MONITORING_START_DATETIME = deployment_datetime,
    MONITORING_END_DATETIME = recovery_datetime,
    RECORDING_DURATION_SECONDS = NA_character_,
    RECORDING_INTERVAL_SECONDS = NA_character_,
    DEPLOYMENT_COMMENTS = NA_character_
  )
skimr::skim(pacm_metadata)

analyses_detections <- analyses |> 
  select(deployment_code, analysis_sound_source_code = analysis_sound_source_codes) |> 
  separate_longer_delim(analysis_sound_source_code, delim = ",") |> 
  distinct() |>
  left_join(
    deployments_recordings |> 
      select(deployment_code, recording_dates),
    by = "deployment_code"
  ) |> 
  left_join(
    detections |> 
      remove_empty("cols") |> 
      nest(raw_detections = -c(deployment_code, detection_sound_source_code)),
    by = c("deployment_code", "analysis_sound_source_code" = "detection_sound_source_code")
  ) |> 
  mutate(
    detections = map2(recording_dates, raw_detections, function (recording_dates, raw_detections) {
      analysis_dates <- tibble(
        date = recording_dates,
        detection_result_code = "NOT_DETECTED",
      ) |> 
        complete(date = seq.Date(min(recording_dates), max(recording_dates), by = "1 day"), fill = list(detection_result_code = "NOT_AVAILABLE"))

      if (is.null(raw_detections)) {
        detections <- tibble()
      } else {
        detections <- raw_detections |> 
          transmute(
            date = as_date(ymd_hms(detection_start_datetime)),
            detection_start_datetime,
            detection_end_datetime,
            detection_effort_secs,
            detection_result_code,
            detection_call_type_code
          )
        analysis_dates <- analysis_dates |> 
          filter(!date %in% detections$date)
      }
      analysis_detections <- analysis_dates |> 
        transmute(
          detection_start_datetime = paste(date, "00:00:00Z"),
          detection_end_datetime = paste(date, "23:59:59Z"),
          detection_effort_secs = "86400",
          detection_call_type_code = NA_character_,
          detection_result_code
        ) |> 
        bind_rows(detections)
    })
  ) |> 
  print()

analyses_detections |> 
  select(deployment_code, analysis_sound_source_code, detections) |> 
  unnest(detections) |>
  tabyl(analysis_sound_source_code, detection_result_code)

# only DETECTED can have multiple detections per day
stopifnot(
  analyses_detections |> 
    select(deployment_code, analysis_sound_source_code, detections) |> 
    unnest(detections) |> 
    mutate(date = as_date(ymd_hms(detection_start_datetime))) |> 
    add_count(deployment_code, analysis_sound_source_code, date) |>
    arrange(deployment_code, analysis_sound_source_code, date) |>
    filter(n > 1) |> 
    pull(detection_result_code) |> 
    unique() == "DETECTED"
)

pacm_detectiondata <- analyses |> 
  distinct(
    deployment_code,
    detector_codes,
    analysis_protocol_reference,
    analysis_min_frequency_khz,
    analysis_max_frequency_khz,
    analysis_sample_rate_khz,
    analysis_processing_code
  ) |> 
  left_join(
    analyses_detections |> 
      select(deployment_code, analysis_sound_source_code, detections) |> 
      unnest(detections) |> 
      select(-date),
    by = c("deployment_code")
  ) |> 
  transmute(
    UNIQUE_ID = deployment_code,
    ANALYSIS_TIME_ZONE = NA_character_,
    DETECTION_METHOD = detector_codes, 
    PROTOCOL_REFERENCE = analysis_protocol_reference,
    DETECTION_SOFTWARE_NAME = "CHORUS BioSound",
    DETECTION_SOFTWARE_VERSION = NA_character_,
    MIN_ANALYSIS_FREQUENCY_RANGE_HZ = as.numeric(analysis_min_frequency_khz) * 1000,
    MAX_ANALYSIS_FREQUENCY_RANGE_HZ = as.numeric(analysis_max_frequency_khz) * 1000,
    ANALYSIS_SAMPLING_RATE_HZ = as.numeric(analysis_sample_rate_khz) * 1000,
    QC_PROCESSING = analysis_processing_code,

    ANALYSIS_PERIOD_START_DATETIME = detection_start_datetime,
    ANALYSIS_PERIOD_END_DATETIME = detection_end_datetime,
    ANALYSIS_PERIOD_EFFORT_SECONDS = detection_effort_secs,
    SPECIES_CODE = analysis_sound_source_code,
    CALL_TYPE_CODE = detection_call_type_code,
    ACOUSTIC_PRESENCE = case_when(
      detection_result_code == "DETECTED" ~ "y",
      TRUE ~ detection_result_code
    )
  )
skimr::skim(pacm_detectiondata)

pacm_detectiondata |>
  tabyl(SPECIES_CODE, ACOUSTIC_PRESENCE)


convert_legacy_submission(
  dir,
  metadata = pacm_metadata,
  detectiondata = pacm_detectiondata,
  organization_code = "RPS_TT",
  project_funding = NA_character_
)
