library(tidyverse)
library(lubridate)
library(readxl)
library(janitor)

DATA_DIR <- config::get("data_dir")

# load --------------------------------------------------------------------

df_raw <- read_excel(
  file.path(DATA_DIR, "towed", "Towed_Array_effort_Walker_Website_Daily_Resolution.xlsx"),
  sheet = "Towed_array_metadata"
) %>% 
  janitor::clean_names()


cruise_dates <- read_xlsx(
  file.path(DATA_DIR, "towed", "Towed_Array_effort_Walker_Website_Daily_Resolution.xlsx"),
  sheet = "Cruise_dates"
) %>% 
  clean_names() %>% 
  mutate(across(c(start, end), as_date)) %>% 
  transmute(
    id = if_else(
      cruise %in% c("GU1303", "GU1605"),
      str_c("SEFSC_", cruise, sep = ""),
      str_c("NEFSC_", cruise, sep = "")
    ),
    start,
    end
  ) %>% 
  arrange(id, start) %>% 
  group_by(id) %>% 
  mutate(leg = row_number()) %>% 
  ungroup() %>% 
  rowwise() %>% 
  mutate(
    date = list(seq.Date(start, end, by = "day"))
  ) %>% 
  unnest(date) %>% 
  select(-start, -end) %>% 
  nest(cruise_dates = c(leg, date))


# clean -------------------------------------------------------------------

df <- df_raw %>% 
  transmute(
    theme = species,
    id = project,
    project,
    site_id = NA_character_,
    latitude = NA_real_,
    longitude = NA_real_,
    
    monitoring_start_datetime = as_date(monitoring_start_datetime),
    monitoring_end_datetime = as_date(monitoring_end_datetime),
    
    platform_type = case_when(
      platform_type == "Towed Array, linear" ~ "towed",
      TRUE ~ NA_character_
    ),
    platform_id = NA_character_,
    water_depth_meters = NA_real_,
    recorder_depth_meters = NA_real_,
    
    instrument_type,
    instrument_id = NA_character_,
    sampling_rate_hz,
    analysis_sampling_rate_hz,
    soundfiles_timezone,
    duty_cycle_seconds,
    channel = NA_character_,
    qc_data,
    
    data_poc_name,
    data_poc_affiliation,
    data_poc_email,
    
    submitter_name,
    submitter_affiliation,
    submitter_email,
    submission_date = as_date(submission_date),
    
    analyzed = as.logical(analyzed),
    call_type,
    detection_method,
    protocol_reference
  ) %>%
  left_join(cruise_dates, by = "id") %>% 
  group_by(theme, id) %>% 
  mutate(
    analysis_start_date = if_else(analyzed, ymd(map(cruise_dates, ~ as.character(min(.x$date)))), NA_Date_),
    analysis_end_date = if_else(analyzed, ymd(map(cruise_dates, ~ as.character(max(.x$date)))), NA_Date_)
  )
  

janitor::tabyl(df, id, theme)
janitor::tabyl(df, analyzed, theme)
janitor::tabyl(df, platform_type, theme)
janitor::tabyl(df, detection_method, theme)
janitor::tabyl(df, instrument_type, theme)
janitor::tabyl(df, analyzed, analysis_start_date)

df %>% 
  filter(analyzed) %>% 
  janitor::tabyl(id, theme)
df %>% 
  filter(analyzed) %>% 
  janitor::tabyl(analyzed, theme)
df %>% 
  filter(analyzed) %>% 
  janitor::tabyl(platform_type, theme)
df %>% 
  filter(analyzed) %>% 
  janitor::tabyl(detection_method, theme)
df %>% 
  filter(analyzed) %>% 
  janitor::tabyl(instrument_type, theme)

# export ------------------------------------------------------------------

df %>% 
  saveRDS("data/towed/deployments.rds")

