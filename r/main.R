# load data from csv, and export for web app

library(tidyverse)
library(lubridate)

df_csv <- read_csv("~/Dropbox/Work/nefsc/transfers/20191011 - data files/NEFSC_NARW_presence_all_2018-10-30.csv", col_types = cols(
  .default = col_character(),
  PLATFORM_ID = col_logical(),
  SITE_ID = col_character(),
  INSTRUMENT_ID = col_character(),
  CHANNEL = col_double(),
  LATITUDE = col_double(),
  LONGITUDE = col_double(),
  WATER_DEPTH_METERS = col_double(),
  RECORDER_DEPTH_METERS = col_double(),
  SAMPLING_RATE_HZ = col_double(),
  ANALYSIS_PERIOD_EFFORT_SECONDS = col_double(),
  N_VALIDATED_DETECTIONS = col_double()
)) %>% 
  janitor::clean_names()

glimpse(df_csv)

df <- df_csv %>% 
  select(
    project,
    site_id,
    platform_type,
    latitude,
    longitude,
    water_depth_meters,
    detection_method,
    monitoring_start_datetime,
    monitoring_end_datetime,
    analysis_period_start_date_time,
    analysis_period_end_date_time,
    n_validated_detections,
    narw_presence
  ) %>% 
  mutate(
    monitoring_start_datetime = mdy_hm(monitoring_start_datetime),
    monitoring_end_datetime = mdy_hm(monitoring_end_datetime),
    analysis_period_start_date_time = mdy_hm(analysis_period_start_date_time),
    analysis_period_end_date_time = mdy_hm(analysis_period_end_date_time),
    deployment = str_c(project, coalesce(site_id, "N/A"), round(latitude, 2), round(longitude, 2), format(monitoring_start_datetime, "%Y%m%d")),
    deployment_id = as.numeric(factor(deployment))
  ) %>% 
  filter(
    !is.na(latitude),
    !is.na(longitude),
    !is.na(analysis_period_start_date_time),
    !is.na(analysis_period_end_date_time)
  )

# failed to parse
df_csv %>% 
  filter(is.na(mdy_hm(monitoring_end_datetime)))
df_csv %>% 
  filter(is.na(mdy_hm(analysis_period_start_date_time)))
df_csv %>% 
  filter(is.na(mdy_hm(analysis_period_end_date_time)))
df_csv %>% 
  filter(is.na(latitude))
df_csv %>% 
  filter(is.na(longitude))
df_csv %>% 
  filter(is.na(site_id))

# sites with differing lat/lon
df_csv %>% 
  mutate(monitoring_start = format(mdy_hm(monitoring_start_datetime), "%Y%m%d")) %>% 
  select(project, site_id, latitude, longitude, monitoring_start) %>% 
  distinct() %>% 
  group_by(project, site_id) %>% 
  mutate(n = n()) %>% 
  ungroup() %>% 
  filter(n > 1)

df_csv %>% 
  select(project, site_id, latitude, longitude) %>% 
  distinct() %>% 
  group_by(site_id)

df_csv %>% 
  select(project, site_id, latitude, longitude) %>% 
  distinct() %>% 
  group_by(project) %>% 
  mutate(n = n()) %>% 
  filter(n > 1)

table(df$detection_method)
table(df$platform_type)

df_out <- df %>% 
  select(
    project,
    deployment_id,
    site_id,
    latitude,
    longitude,
    start = analysis_period_start_date_time,
    end = analysis_period_end_date_time,
    detections = n_validated_detections,
    presence = narw_presence
  ) %>% 
  mutate(
    presence = case_when(
      presence == "Detected" ~ "yes",
      presence == "Not Detected" ~ "no",
      presence == "Possibly Detected" ~ "maybe",
      TRUE ~ "unknown"
    ),
    detections = coalesce(detections, 0),
    duration_sec = as.numeric(difftime(end, start, units = "sec"))
  )

summary(df_out)

table(df_out$deployment_id)
table(df_out$project)
table(df_out$site_id)
table(df_out$presence)
table(df_out$detections)
table(df_out$duration_sec) # some are 6 days long

df %>% 
  group_by(site_id, latitude, longitude, monitoring_start_datetime) %>% 
  count() %>% 
  View()

df %>% 
  group_by(site_id, latitude, longitude, monitoring_start_datetime) %>% 
  count() %>% 
  group_by()

df %>% 
  group_by(latitude, longitude) %>% 
  mutate(
    n = length(unique(site_id))
  ) %>% 
  filter(n > 1)

df_out %>% 
  filter(duration_sec > 86400) %>% 
  select(project, deployment_id, site_id) %>% 
  distinct()

df_out %>% 
  write_csv("../public/data/narw.csv")
