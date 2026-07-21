library(tidyverse)

dir <- "data-raw/legacy/_rejected/THMAH_20241028/"

raw_metadata <- readxl::read_excel(file.path(dir, "raw/THMAH_20241028_METADATA.xlsx"))
raw_detectiondata <- readxl::read_excel(file.path(dir, "raw/THMAH_20241028_DETECTIONDATA.xlsx"))

raw_metadata |> 
  tabyl(UNIQUE_ID)

raw_metadata |>
  mutate(
    PLATFORM_NO = toupper(PLATFORM_NO),
    MONITORING_START_DATETIME = case_when(
      str_starts(MONITORING_START_DATETIME, "2023-09-07T21:46") ~ "2023-09-07T21:46:00",
      TRUE ~ MONITORING_START_DATETIME
    ),
    MONITORING_END_DATETIME = case_when(
      str_starts(MONITORING_END_DATETIME, "2024-04-30T23:59") ~ "2024-04-30T23:59:00",
      TRUE ~ MONITORING_END_DATETIME
    ),
    across(c(MONITORING_START_DATETIME, MONITORING_END_DATETIME), ~ floor_date(ymd_hms(.x), unit = "hours"))
  ) |> 
  distinct(
    SITE_ID, PROJECT,
    DATA_POC_NAME, DATA_POC_AFFILIATION, DATA_POC_EMAIL,
    STATIONARY_OR_MOBILE, PLATFORM_TYPE, PLATFORM_NO,
    MONITORING_START_DATETIME, MONITORING_END_DATETIME,
    LATITUDE, LONGITUDE,

    INSTRUMENT_TYPE,
    # INSTRUMENT_ID,
    # CHANNEL,
    MONITORING_START_DATETIME,
    MONITORING_END_DATETIME,
    SOUNDFILES_TIMEZONE,
    LATITUDE,
    LONGITUDE,
    WATER_DEPTH_METERS,
    RECORDER_DEPTH_METERS
    # SAMPLING_RATE_HZ,
    # RECORDING_DURATION_SECONDS,
    # RECORDING_INTERVAL_SECONDS,
    # SAMPLE_BITS,
    # DEPLOYMENT_COMMENTS,
    # SUBMITTER_NAME,
    # SUBMITTER_AFFILIATION,
    # SUBMITTER_EMAIL,
    # SUBMISSION_DATE
  ) |>
  arrange(PLATFORM_NO, SITE_ID, MONITORING_START_DATETIME) |>
  view()
# NOTE: depths, lat/lon, sites, platforms seem to be mixed up. Seconds are invalid. Too many data quality issues.

# dir.create(file.path(dir, "clean"), showWarnings = FALSE)
# write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
# write_csv(detectiondata, file.path(dir, "clean/detectiondata.csv"), na = "")
