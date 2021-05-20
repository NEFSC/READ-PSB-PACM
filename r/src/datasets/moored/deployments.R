library(tidyverse)
library(lubridate)
library(janitor)

files <- config::get("files")

# load --------------------------------------------------------------------

df_csv <- read_csv(
  file.path(files$root, files$moored$metadata),
  col_types = cols(.default = col_character())
) %>% 
  janitor::clean_names()


# transform ---------------------------------------------------------------

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
    latitude = parse_number(latitude),
    longitude = parse_number(longitude),
    
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime),
    
    platform_type = fct_recode(platform_type, mooring = "Mooring", buoy = "surface buoy"),
    platform_id,

    water_depth_meters = parse_number(water_depth_meters),
    recorder_depth_meters = parse_number(recorder_depth_meters),
    instrument_type,
    instrument_id,
    sampling_rate_hz = as.numeric(sampling_rate_hz),
    analysis_sampling_rate = 2000, # TODO: add to metadata
    soundfiles_timezone,
    duty_cycle_seconds,
    channel,
    qc_data,
    
    data_poc_name,
    data_poc_affiliation,
    data_poc_email,
    
    submitter_name,
    submitter_affiliation,
    submitter_email,
    submission_date = ymd(submission_date),
    
    # species specific
    detection_method,
    protocol_reference,
    call_type
  )


# summary -----------------------------------------------------------------

tabyl(df, theme)
tabyl(df, platform_type, theme)
tabyl(df, call_type, theme)
tabyl(df, detection_method, theme)
tabyl(df, protocol_reference, theme)
tabyl(df, instrument_type, theme)


# export ------------------------------------------------------------------

write_rds(df, "data/datasets/moored/deployments.rds")
