library(tidyverse)
library(lubridate)
library(janitor)

files <- config::get("files")

# load --------------------------------------------------------------------

df_csv <- read_csv(
  file.path(files$root, files$dfo$metadata),
  col_types = cols(.default = col_character())
) %>% 
  janitor::clean_names()


# transform ---------------------------------------------------------------

df <- df_csv %>% 
  transmute(
    theme = "beaked",
    id = unique_id,
    project,
    site_id,
    latitude = parse_number(latitude),
    longitude = parse_number(longitude),
    
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime),
    
    platform_type = case_when(
      platform_type == "Bottom-Mounted" ~ "mooring",
      TRUE ~ platform_type
    ),
    platform_id = platform_no,
    water_depth_meters = parse_number(water_depth_meters),
    recorder_depth_meters = parse_number(recorder_depth_meters),
    
    instrument_type,
    instrument_id,
    sampling_rate_hz = parse_number(sampling_rate_hz),
    soundfiles_timezone,
    duty_cycle_seconds = NA_character_, # missing
    channel,
    
    data_poc_name,
    data_poc_affiliation,
    data_poc_email,
    
    submitter_name,
    submitter_affiliation,
    submitter_email,
    submission_date = ymd(submission_date),
  )


# summary -----------------------------------------------------------------

summary(df)
tabyl(df, theme)
tabyl(df, platform_type, theme)

# export ------------------------------------------------------------------

write_rds(df, "data/datasets/dfo/deployments.rds")

