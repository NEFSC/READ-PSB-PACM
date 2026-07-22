# GARDLINE_20250815 - ORSTED Sunrise Wind, submitted via GARDLINE in MAKARA_1.2
# format, converted to PARS (T3.3).
#
# raw/ holds the makara-format METADATA/DETECTIONDATA workbooks (immutable). This
# clean.R reshapes them to PARS:
#   - metadata is recording-grain (a moored surface buoy drifts within its watch
#     circle, so position varies slightly across recordings while site_code is
#     constant); it is aggregated to one deployment per code, taking the first
#     position as the nominal mooring point and the union of device codes
#   - coordinates are UTM Zone 19N northing/easting in metres (EPSG:32619,
#     confirmed by the land/ocean test - 19N lands offshore at Sunrise Wind,
#     18N is inland Pennsylvania); reprojected to WGS84
#   - recording and analysis parameters were not submitted (the "fill in missing
#     recordings, analyses" note); they relax to NA under PARS_LEGACY
#   - recovery_datetime is absent, so monitoring_end is bounded by the last
#     recording start and the last detection
#   - only positive (DETECTED) event detections were submitted, so analyses carry
#     detected days with no absence coverage (accepted gap, T3.3)

library(tidyverse)
library(readxl)
library(sf)

dir <- "data-raw/pars/GARDLINE_20250815"

# Excel stores datetimes as serials; read natively so readxl parses them to UTC
# POSIXct/Date, then stamp as tz-aware PARS timestamps
stamp_utc <- function (x) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%S+0000", tz = "UTC")
}

raw_md <- read_excel(
  list.files(file.path(dir, "raw"), pattern = "METADATA", full.names = TRUE)
)
raw_dd <- read_excel(
  list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE)
)

# last detection per deployment helps bound monitoring_end (recovery is absent)
det_bound <- raw_dd |>
  group_by(deployment_code) |>
  summarise(det_end = max(as.POSIXct(detection_end_datetime, tz = "UTC")), .groups = "drop")

deployments <- raw_md |>
  mutate(
    dep_dt = as.POSIXct(deployment_datetime, tz = "UTC"),
    northing = as.numeric(deployment_latitude),
    easting = as.numeric(deployment_longitude)
  ) |>
  group_by(deployment_code) |>
  summarise(
    organization_code = first(organization_code),
    project_code = first(project_code),
    site_code = first(site_code),
    platform_type = first(deployment_platform_type_code),
    water_depth = first(deployment_water_depth_m),
    monitoring_start = min(dep_dt, na.rm = TRUE),
    last_recording = max(dep_dt, na.rm = TRUE),
    device_codes = paste(sort(unique(deployment_device_codes)), collapse = ","),
    northing = first(northing),
    easting = first(easting),
    .groups = "drop"
  ) |>
  left_join(det_bound, by = "deployment_code") |>
  mutate(monitoring_end = pmax(last_recording, det_end, na.rm = TRUE))

# UTM 19N (metres) -> WGS84 (decimal degrees)
wgs84 <- deployments |>
  st_as_sf(coords = c("easting", "northing"), crs = 32619) |>
  st_transform(4326) |>
  st_coordinates()

metadata <- deployments |>
  transmute(
    deployment_organization_code = organization_code,
    deployment_code,
    project_name = project_code,
    site_code,
    monitoring_start_datetime = stamp_utc(monitoring_start),
    monitoring_end_datetime = stamp_utc(monitoring_end),
    deployment_platform_type_code = platform_type,
    deployment_platform_id = NA_character_,
    deployment_water_depth_m = water_depth,
    deployment_latitude = wgs84[, "Y"],
    deployment_longitude = wgs84[, "X"],
    dynamic_management_platform = NA_character_,
    deployment_url = NA_character_,
    recording_device_code = device_codes,
    recording_device_type_code = NA_character_,
    recording_duration_secs = NA_character_,
    recording_interval_secs = NA_character_,
    recording_sample_rate_khz = NA_character_,
    recording_bit_depth = NA_character_,
    recording_n_channels = NA_character_,
    recording_timezone = NA_character_,
    recording_device_depth_m = NA_character_,
    points_of_contact = NA_character_,
    project_funding = NA_character_
  )

detectiondata <- raw_dd |>
  mutate(
    ds = as.POSIXct(detection_start_datetime, tz = "UTC"),
    de = as.POSIXct(detection_end_datetime, tz = "UTC"),
    # the submitter prefixed call types with the sound source; UNDO (odontocete)
    # calls take the generic OD_ codes. UNBA_MIX (unid baleen) has no official
    # code and is preserved as a supplement code (DETECTED rows must carry one)
    call_type = case_when(
      detection_call_type_code == "UNDO_MIX" ~ "OD_MIX",
      detection_call_type_code == "UNDO_WHIS" ~ "OD_WHIS",
      TRUE ~ detection_call_type_code
    )
  ) |>
  group_by(deployment_code, detection_sound_source_code) |>
  mutate(analysis_start = min(ds), analysis_end = max(de)) |>
  ungroup() |>
  transmute(
    analysis_organization_code = organization_code,
    deployment_code,
    analysis_sound_source_codes = detection_sound_source_code,
    analysis_start_datetime = stamp_utc(analysis_start),
    analysis_end_datetime = stamp_utc(analysis_end),
    analysis_sample_rate_khz = NA_character_,
    analysis_min_frequency_khz = NA_character_,
    analysis_max_frequency_khz = NA_character_,
    analysis_processing_code = NA_character_,
    analysis_protocol_reference = NA_character_,
    analysis_citations = NA_character_,
    analysis_detector_code = NA_character_,
    analysis_detector_version = NA_character_,
    detection_start_datetime = stamp_utc(ds),
    detection_end_datetime = stamp_utc(de),
    detection_effort_secs = as.character(as.numeric(de - ds, units = "secs")),
    detection_sound_source_code,
    detection_call_type_code = call_type,
    detection_n_validated,
    detection_result_code,
    localization_method_code = NA_character_,
    localization_latitude = NA_character_,
    localization_longitude = NA_character_,
    localization_distance_m = NA_character_
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detectiondata, file.path(dir, "clean/detectiondata.csv"), na = "")
