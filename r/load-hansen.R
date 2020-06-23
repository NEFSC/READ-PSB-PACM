# load buoy and glider data from Hansen's dataset

library(tidyverse)
library(lubridate)
library(jsonlite)

df_csv <- read_csv(
  "~/Dropbox/Work/nefsc/transfers/20200113 - hansen pam dataset/Hansen Johnson - narw_pam_database.csv",
  col_types = cols(
    .default = col_character(),
    CHANNEL = col_double(),
    LATITUDE = col_double(),
    LONGITUDE = col_double(),
    WATER_DEPTH_METERS = col_double(),
    RECORDER_DEPTH_METERS = col_double(),
    SAMPLING_RATE_HZ = col_double(),
    ANALYSIS_PERIOD_EFFORT_SECONDS = col_double(),
    N_VALIDATED_DETECTIONS = col_double(),
    MONITORING_DURATION = col_double(),
    SUBMISSION_DATE = col_date()
  )
) %>% 
  janitor::clean_names()

df <- df_csv %>% 
  filter(instrument_type %in% c("DMON", "Autobuoy")) %>% 
  mutate(
    species = "narw",
    date = ymd(analysis_date),
    detection = case_when(
      narw_presence == "detected" ~ "yes",
      narw_presence == "possible" ~ "maybe",
      narw_presence == "undetected" ~ "no",
      TRUE ~ "unknown"
    ),
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime)
  ) %>% 
  rename(
    analysis_period_start_date_time = analysis_period_start_datetime, # convert to same column names as Gen
    analysis_period_end_date_time = analysis_period_end_datetime
  ) %>%
  select(-year, -mday, -monitoring_duration, -narw_presence, -analysis_date) # drop these columns

# gliders -----------------------------------------------------------------

df_gliders <- df %>% 
  filter(platform_type == "slocum")

# compute median lat/lon by project,date
df_gliders_day <- df_gliders %>% 
  group_by(project, site_id, platform_type, date, species) %>% 
  summarise(
    latitude = median(latitude, na.rm = TRUE),
    longitude = median(longitude, na.rm = TRUE),
    detection = case_when(
      any(detection == "yes") ~ "yes",
      any(detection == "maybe") ~ "maybe",
      any(detection == "no") ~ "no",
      TRUE ~ "unknown"
    )
  ) %>% 
  ungroup() %>% 
  filter(!is.na(latitude), !is.na(longitude)) %>% 
  arrange(project, site_id, date) %>% 
  group_by(project, site_id) %>% 
  mutate(
    next_latitude = lead(latitude),
    next_longitude = lead(longitude),
  ) %>% 
  ungroup()

df_gliders_day %>%
  ggplot(aes(longitude, latitude, xend = next_longitude, yend = next_latitude)) +
  geom_segment() +
  geom_point(aes(color = detection))

# time gaps
df_gliders_day %>% 
  group_by(project) %>% 
  mutate(
    diff_day = c(NA, diff(date))
  ) %>% 
  filter(diff_day > 1)

df_glider_detections <- df_gliders_day %>% 
  select(project, site_id, platform_type, date, species, latitude, longitude, detection)
stopifnot(all(df_glider_detections$detection %in% c("yes", "no", "maybe")))
stopifnot(all(!is.na(df_glider_detections[, c("latitude", "longitude")])))

df_glider_deployments <- df_gliders %>% 
  select(
    c(
      "project", "data_poc_name", "data_poc_affiliation", "data_poc_email", 
      "platform_type", "platform_id", "site_id", "instrument_type", 
      "instrument_id", "channel", "submitter_name", "submitter_affiliation", 
      "submitter_email", "submission_date", "latitude", "longitude", 
      "water_depth_meters", "recorder_depth_meters", "soundfiles_timezone", 
      "sampling_rate_hz", "duty_cycle_seconds", "monitoring_start_datetime", 
      "monitoring_end_datetime", "qc_data", "detection_method", "protocol_reference"
    )
  ) %>% 
  mutate(
    latitude = NA,
    longitude = NA
  ) %>% 
  distinct()
stopifnot(all(!duplicated(df_glider_deployments$project)))

# buoy --------------------------------------------------------------------

df_buoy <- df %>% 
  filter(platform_type != "slocum") %>% 
  mutate(
    platform_type = if_else(
      project == "CORNELL_TSS_AUTOBUOYS",
      "buoy",
      platform_type
    )
  )

df_buoy_day <- df_buoy %>% 
  group_by(project, site_id, platform_type, date, species) %>% 
  summarise(
    latitude = median(latitude, na.rm = TRUE),
    longitude = median(longitude, na.rm = TRUE),
    detection = case_when(
      any(detection == "yes") ~ "yes",
      any(detection == "maybe") ~ "maybe",
      any(detection == "no") ~ "no",
      TRUE ~ "unknown"
    )
  ) %>% 
  ungroup() %>% 
  filter(!is.na(latitude), !is.na(longitude))

df_buoy_day %>%
  ggplot(aes(longitude, latitude)) +
  geom_point(aes(color = detection)) + 
  facet_wrap(vars(detection))

df_buoy_detections <- df_buoy_day %>% 
  select(project, site_id, platform_type, date, species, detection)
stopifnot(all(df_buoy_detections$detection %in% c("yes", "no", "maybe")))

df_buoy_deployments <- df_buoy %>% 
  select(
    c(
      "project", "data_poc_name", "data_poc_affiliation", "data_poc_email", 
      "platform_type", "platform_id", "site_id", "instrument_type", 
      "instrument_id", "channel", "submitter_name", "submitter_affiliation", 
      "submitter_email", "submission_date", "latitude", "longitude", 
      "water_depth_meters", "recorder_depth_meters", "soundfiles_timezone", 
      "sampling_rate_hz", "duty_cycle_seconds", "monitoring_start_datetime", 
      "monitoring_end_datetime", "qc_data", "detection_method", "protocol_reference"
    )
  ) %>% 
  distinct()
stopifnot(all(!duplicated(str_c(df_buoy_deployments$project, df_buoy_deployments$platform_id))))


# export ------------------------------------------------------------------

list(
  glider = list(
    tracks = df_gliders_day %>% 
      select(project, site_id, platform_type, date, latitude, longitude),
    detections = df_glider_detections %>% 
      filter(detection == "yes"),
    deployments = df_glider_deployments
  ),
  buoy = list(
    detections = df_buoy_detections,
    deployments = df_buoy_deployments
  )
) %>% 
  saveRDS("rds/hansen.rds")
