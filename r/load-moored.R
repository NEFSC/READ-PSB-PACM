# load buoy/mooring dataset

library(tidyverse)
library(lubridate)
library(logger)

log_threshold(DEBUG)


# load metadata -----------------------------------------------------------

df_meta_csv <- read_csv(
  "~/Dropbox/Work/nefsc/transfers/20200728 - updated moored dataset/Moored_metadata_2020-07-28.csv",
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
    # normalize text
    platform_type = tolower(platform_type),
    duty_cycle_seconds = tolower(duty_cycle_seconds)
  ) %>% 
  select(unique_id, everything()) # bring unique_id to first column

df_meta_all <- df_meta_csv %>% 
  mutate(
    submission_date = ymd(submission_date),
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime)
  )

# load detection data -----------------------------------------------------

df_detect_csv <- read_csv(
  "~/Dropbox/Work/nefsc/transfers/20200728 - updated moored dataset/Moored_detection_data_2020-07-28.csv",
  col_types = cols(
    .default = col_character(),
    ANALYSIS_PERIOD_EFFORT_SECONDS = col_double(),
    NARW_N_VALIDATED_DETECTIONS = col_integer()
  )
) %>% 
  janitor::clean_names()

df_detect_all <- df_detect_csv %>% 
  mutate(
    analysis_period_start_datetime = ymd_hms(analysis_period_start_datetime),
    analysis_period_end_datetime = ymd_hms(analysis_period_end_datetime)
  )


# screen projects ---------------------------------------------------------

# only projects with detection data
projects_without_data <- setdiff(unique(df_meta_all$unique_id), unique(df_detect$unique_id))
log_info("excluding projects with no detection data (n = {length(projects_without_data)})")

# only projects with valid lat/lon
projects_invalid_latlon <- df_meta_all %>% 
  filter(is.na(latitude) | is.na(longitude)) %>% 
  pull(unique_id)
log_info("excluding projects with invalid lat/lon (n = {length(projects_invalid_latlon)})")

df_meta <- df_meta_all %>% 
  filter(!unique_id %in% c(projects_without_data, projects_invalid_latlon))

df_detect <- df_detect_all %>% 
  filter(unique_id %in% df_meta$unique_id) %>% 
  rename_with(
    ~ str_replace(., "_", ":"),
    starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
  ) %>% 
  pivot_longer(
    starts_with(c("narw", "humpback", "sei", "fin", "blue")),
    names_to = c("species", ".value"),
    names_sep = ":"
  ) %>% 
  filter(!is.na(presence)) %>% 
  mutate(
    presence = case_when(
      presence == "Not Detected" ~ "no",
      presence == "Possibly Detected" ~ "maybe",
      presence == "Detected" ~ "yes",
      TRUE ~ NA_character_
    )
  )


# meta summary ------------------------------------------------------------

# unique values
janitor::tabyl(df_meta$platform_type)
janitor::tabyl(df_meta$instrument_type)
janitor::tabyl(df_meta$channel)
janitor::tabyl(df_meta$soundfiles_timezone)
janitor::tabyl(df_meta$duty_cycle_seconds)
janitor::tabyl(df_meta$qc_data)

# timestamps
df_meta %>% 
  select(where(is.Date)) %>%
  table()
df_meta %>% 
  select(where(is.POSIXct)) %>%
  summary()

# numeric values
df_meta %>% 
  select(where(is.numeric)) %>%
  summary()


# detect summary ----------------------------------------------------------

df_detect %>% 
  select(where(is.POSIXct)) %>%
  summary()

df_detect %>% 
  janitor::tabyl(presence, species) %>% 
  janitor::adorn_totals(where = c("row"))

df_detect %>% 
  janitor::tabyl(presence, species) %>% 
  janitor::adorn_percentages("row") %>% 
  janitor::adorn_pct_formatting(digits = 0)

# n_validated_detections only used for (some) NARW detections
df_detect%>% 
  janitor::tabyl(n_validated_detections, species)

df_detect %>% 
  janitor::tabyl(call_type, species)

df_detect %>% 
  janitor::tabyl(detection_method, species)

df_detect %>% 
  janitor::tabyl(protocol_reference, detection_method)


# qaqc --------------------------------------------------------------------

stopifnot(exprs = {
  all(!duplicated(df_meta$unique_id))
  all(!is.na(select(df_meta, unique_id, starts_with("monitoring_"), latitude, longitude)))
  all(df_meta$longitude < 0)
  
  identical(sort(unique(df_meta$unique_id)), sort(unique(df_detect$unique_id)))
  
  all(!is.na(select(df_detect, unique_id, starts_with("analysis_period"), species, presence)))
  all(unique(df_detect$presence) %in% c("yes", "no", "maybe"))
})

df_detect %>% 
  distinct(unique_id, detection_method) %>% 
  group_by(unique_id) %>% 
  add_count() %>%
  filter(n > 1)

df_detect %>% 
  distinct(unique_id, species, protocol_reference) %>% 
  group_by(unique_id, species) %>% 
  add_count() %>%
  filter(n > 1)


detections_not_daily <- df_detect %>%
  filter(analysis_period_effort_seconds < 86400) %>%
  pull(unique_id) %>% 
  unique()

df_meta %>% 
  filter(unique_id %in% detections_not_daily)

# export ------------------------------------------------------------------

list(
  meta = df_meta,
  detect = df_detect
) %>% 
  saveRDS("rds/moored.rds")
