# load buoy/mooring dataset

library(tidyverse)
library(lubridate)


# load csv ----------------------------------------------------------------

df_moored_meta_csv <- read_csv(
  "~/Dropbox/Work/nefsc/transfers/20200724 - multispecies mooring and glider/Moored_metadata_2020-07-24.csv",
  col_types = cols(
    .default = col_character(),
    CHANNEL = col_integer(),
    LATITUDE = col_double(),
    LONGITUDE = col_double(),
    WATER_DEPTH_METERS = col_double(),
    RECORDER_DEPTH_METERS = col_double(),
    SAMPLING_RATE_HZ = col_double()
  )
) %>% 
  janitor::clean_names() %>% 
  mutate(
    duty_cycle_seconds = tolower(duty_cycle_seconds)
  )

df_moored_meta <- df_moored_meta_csv %>% 
  mutate(
    submission_date = ymd(submission_date),
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime)
  )

# unique values
janitor::tabyl(df_moored_meta$platform_type)
janitor::tabyl(df_moored_meta$instrument_type)
janitor::tabyl(df_moored_meta$channel)
janitor::tabyl(df_moored_meta$soundfiles_timezone)
janitor::tabyl(df_moored_meta$duty_cycle_seconds)
janitor::tabyl(df_moored_meta$qc_data)

# timestamps
df_moored_meta %>% 
  select(where(is.Date)) %>%
  table()
df_moored_meta %>% 
  select(where(is.POSIXct)) %>%
  summary()

# numeric values
df_moored_meta %>% 
  select(where(is.numeric)) %>%
  summary()

# missing monitoring start/end datetime
df_moored_meta_csv[is.na(ymd_hms(df_moored_meta_csv$monitoring_start_datetime)) | is.na(ymd_hms(df_moored_meta_csv$monitoring_end_datetime)), ] %>% 
  write_csv("qaqc/20200724/moored-metadata-missing-monitoring-timestamp.csv")

# duplicate project id
df_moored_meta %>%
  group_by(project) %>% 
  add_count() %>% 
  filter(n > 1) %>% 
  arrange(project) %>% 
  select(-n) %>% 
  write_csv("qaqc/20200724/moored-metadata-duplicate-project.csv")

# missing lat/lon
df_moored_meta %>% 
  filter(is.na(latitude) | is.na(longitude)) %>% 
  write_csv("qaqc/20200724/moored-metadata-missing-latlon.csv")

# positive longitude
df_moored_meta %>% 
  filter(longitude > 0) %>% 
  write_csv("qaqc/20200724/moored-metadata-positive-longitude.csv")




# qaqc --------------------------------------------------------------------

# failed to parse
df_csv %>% 
  filter(is.na(ymd_hms(monitoring_end_datetime)))
df_csv %>% 
  filter(is.na(ymd_hms(analysis_period_start_date_time)))
df_csv %>% 
  filter(is.na(ymd_hms(analysis_period_end_date_time)))

df_csv %>% 
  filter(is.na(latitude))
df_csv %>% 
  filter(is.na(longitude))

df_csv %>% 
  filter(is.na(site_id))

# invalid longitude
df_csv %>% 
  filter(longitude > 0) %>% 
  select(project, site_id, latitude, longitude) %>% 
  distinct()

# sites with differing lat/lon
df_csv %>% 
  mutate(monitoring_start = format(ymd_hms(monitoring_start_datetime), "%Y%m%d")) %>% 
  select(project, site_id, latitude, longitude, monitoring_start) %>% 
  distinct() %>% 
  group_by(project, site_id) %>% 
  mutate(n = n()) %>% 
  ungroup() %>% 
  filter(n > 1)

# multiple identical rows with varying fin_presence
df_csv %>% 
  group_by(project, site_id, analysis_period_start_date_time) %>% 
  add_tally() %>% 
  ungroup() %>% 
  filter(n > 1) %>% 
  select(project, site_id, ends_with("presence"), n)


# clean -------------------------------------------------------------------

df <- df_csv %>% 
  mutate(
    site_id = coalesce(site_id, "N/A"),
    longitude = if_else(longitude > 0, -1 * longitude, longitude),
    submission_date = ymd(submission_date),
    platform_type = tolower(platform_type),
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime),
    analysis_period_start_date_time = ymd_hms(analysis_period_start_date_time),
    analysis_period_end_date_time = ymd_hms(analysis_period_end_date_time)
  ) %>% 
  filter(
    !is.na(latitude),
    !is.na(longitude),
    !is.na(analysis_period_start_date_time),
    !is.na(analysis_period_end_date_time)
  ) %>% 
  select(-fin_presence) %>% 
  distinct()

table(df$detection_method)
table(df$platform_type)
table(df$instrument_type)

deployment_variables <- c(
  "project",
  "data_poc_name", 
  "data_poc_affiliation", 
  "data_poc_email", 
  "platform_type", 
  "platform_id",
  "site_id",
  "instrument_type", 
  "instrument_id",
  "channel",
  "submitter_name",
  "submitter_affiliation", 
  "submitter_email",
  "submission_date",
  "latitude",
  "longitude", 
  "water_depth_meters",
  "recorder_depth_meters",
  "soundfiles_timezone", 
  "sampling_rate_hz",
  "duty_cycle_seconds",
  "monitoring_start_datetime", 
  "monitoring_end_datetime",
  "qc_data",
  "detection_method",
  "protocol_reference"
)
detection_variables <- c(
  "project",
  "site_id",
  "platform_type",
  "analysis_period_start_date_time",
  "analysis_period_end_date_time", 
  "analysis_period_effort_seconds", 
  "n_validated_detections",
  "narw_presence", 
  "call_type", 
  "blue_presence",
  "sei_presence",
  "humpback_presence"
)

df_deployments <- df %>% 
  select(deployment_variables) %>% 
  distinct()

stopifnot(
  df_deployments %>% 
    select(project, site_id, latitude, longitude) %>% 
    distinct() %>% 
    group_by(project, site_id) %>% 
    count() %>% 
    filter(n > 1) %>% 
    nrow() == 0
)

df_detections <- df %>% 
  select(detection_variables) %>% 
  transmute(
    project,
    site_id,
    platform_type,
    date = as_date(analysis_period_start_date_time),
    narw_presence,
    blue_presence,
    sei_presence,
    humpback_presence
    # fin_presence
  ) %>% 
  distinct() %>% 
  pivot_longer(ends_with("_presence"), names_to = "species", values_to = "detection", values_drop_na = TRUE) %>% 
  mutate(
    species = str_replace(species, "_presence", ""),
    detection = case_when(
      detection == "Detected" ~ "yes",
      detection == "Not Detected" ~ "no",
      detection == "Possibly Detected" ~ "maybe",
      TRUE ~ NA_character_
    )
  ) %>%
  arrange(project, site_id, date, species)

stopifnot(
  df_detections %>% 
    group_by(project, site_id, date, species) %>% 
    count() %>% 
    filter(n > 1) %>% 
    nrow() == 0
)

# stopifnot(all(!is.na(df_detections)))

glimpse(df_deployments)
glimpse(df_detections)

df_detections %>% 
  janitor::tabyl(detection, species) %>% 
  janitor::adorn_percentages("row") %>% 
  janitor::adorn_pct_formatting(digits = 0)

# export ------------------------------------------------------------------

list(
  detections = df_detections,
  deployments = df_deployments
) %>% 
  saveRDS("rds/gen.rds")
