library(tidyverse)
library(lubridate)
library(readxl)

DATA_DIR <- config::get("data_dir")


# load --------------------------------------------------------------------

df_csv <- read_csv(
  file.path(DATA_DIR, "glider", "Glider_metadata_2020-08-06.csv"),
  col_types = cols(.default = col_character())
) %>% 
  janitor::clean_names()

df <- df_csv %>% 
  rename_with(
    ~ str_replace(., "_", ":"),
    starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
  ) %>%
  pivot_longer(
    starts_with(c("narw", "humpback", "sei", "fin", "blue")),
    names_to = c("theme", ".value"),
    names_sep = ":",
    values_drop_na = TRUE
  ) %>% 
  transmute(
    theme,
    id = unique_id,
    project,
    site_id,
    latitude = NA_real_,
    longitude = NA_real_,
    
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime),
    
    platform_type,
    platform_id,
    water_depth_meters = parse_number(water_depth_meters),
    recorder_depth_meters = parse_number(recorder_depth_meters),
    
    instrument_type,
    instrument_id,
    sampling_rate_hz,
    soundfiles_timezone,
    duty_cycle_seconds,
    channel,
    qc_data,

    detection_method,
    protocol_reference,
    
    data_poc_name,
    data_poc_affiliation,
    data_poc_email,
    
    submitter_name,
    submitter_affiliation,
    submitter_email,
    submission_date = ymd(submission_date)
  )

janitor::tabyl(df, id, theme)
janitor::tabyl(df, platform_type, theme)
janitor::tabyl(df, detection_method, theme)
janitor::tabyl(df, instrument_type, theme)

# export ------------------------------------------------------------------

df %>% 
  saveRDS("data/glider/deployments.rds")

