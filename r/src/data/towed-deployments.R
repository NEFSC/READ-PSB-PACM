library(tidyverse)
library(lubridate)
library(readxl)

DATA_DIR <- config::get("data_dir")


# load --------------------------------------------------------------------

df_beaked <- read_excel(
  file.path(DATA_DIR, "towed", "Towed_Array_effort_Walker_Website_Daily_Resolution.xlsx"),
  sheet = "BW"
) %>% 
  mutate(theme = "beaked")

df_kogia <- read_xlsx(
  file.path(DATA_DIR, "towed", "Towed_Array_effort_Walker_Website_Daily_Resolution.xlsx"),
  sheet = "KOGIA"
) %>% 
  mutate(theme = "kogia")

df_sperm <- read_xlsx(
  file.path(DATA_DIR, "towed", "Towed_Array_effort_Walker_Website_Daily_Resolution.xlsx"),
  sheet = "SPWH"
) %>% 
  mutate(theme = "sperm")


# merge -------------------------------------------------------------------

df_csv <- bind_rows(df_beaked, df_kogia, df_sperm) %>% 
  janitor::clean_names()

df <- df_csv %>% 
  transmute(
    theme,
    id = project,
    project,
    site_id = NA_character_,
    latitude = NA_real_,
    longitude = NA_real_,
    
    monitoring_start_datetime = as_date(monitoring_start_datetime_oracle),
    monitoring_end_datetime = as_date(monitoring_end_datetime_oracle),
    
    platform_type = "towed",
    platform_id = NA_character_,
    water_depth_meters = NA_real_,
    recorder_depth_meters = NA_real_,
    
    instrument_type = recorder_type,
    instrument_id = NA_character_,
    sampling_rate_hz = as.character(sampling_rate_khz * 1000),
    soundfiles_timezone,
    duty_cycle_seconds,
    channel = NA_character_,
    qc_data,
    
    detection_method,
    protocol_reference,
    
    data_poc_name = data_poc,
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
  saveRDS("data/towed/deployments.rds")

