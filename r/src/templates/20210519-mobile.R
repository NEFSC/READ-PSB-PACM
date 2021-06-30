# mobile template

library(tidyverse)
library(lubridate)
library(sf)
library(glue)
library(janitor)
library(jsonlite)
library(writexl)

glider <- read_rds("data/glider.rds")
towed <- read_rds("data/towed.rds")

glider_detections <- read_rds("data/glider/detections.rds")$data
towed_detections <- read_rds("data/towed/detections.rds")$data

glider_tracks <- read_rds("data/glider/tracks.rds")
towed_tracks <- read_rds("data/towed/tracks.rds")

# assume same POC and Submitter values for all recorders?
# assume only analyzed=TRUE?
# analysis_period_effort_seconds can be computed from start/end datetime?

deployments <- bind_rows(
  glider$deployments %>% 
    rename(analysis_sampling_rate_hz = analysis_sampling_rate),
  towed$deployments
)

recorders <- deployments %>% 
  tibble() %>% 
  filter(analyzed) %>% 
  select(
    id,
    project, site_id,
    monitoring_start_datetime, monitoring_end_datetime,
    platform_type, platform_id, water_depth_meters, recorder_depth_meters,
    instrument_type, instrument_id, sampling_rate_hz, soundfiles_timezone,
    duty_cycle_seconds, channel, qc_data
    # starts_with("data_poc_"),
    # starts_with("submitter_"),
    # submission_date
  ) %>% 
  distinct()

recorders %>% 
  add_count(id) %>% 
  filter(n > 1) %>% 
  View
# NEFSC_HB1603: instrument_type varies
# NEFSC_GU1803: qc_data varies

recorders <- recorders %>% 
  group_by(id) %>% 
  slice(1) %>% 
  ungroup()

tracks <- bind_rows(
  glider_tracks$data %>% 
    mutate(recorder_on_off = "ON"),
  towed_tracks$legs %>% 
    mutate(recorder_on_off = if_else(is.na(leg), "OFF", "ON")) %>% 
    select(-date, -leg)
) %>% 
  rename(recorder_id = id) %>% 
  arrange(recorder_id, datetime)

analyses <- deployments %>% 
  tibble() %>% 
  filter(analyzed) %>% 
  select(
    species_group = theme,
    recorder_id = id,
    detection_method, protocol_reference, call_type,
    analysis_sampling_rate_hz,
    analysis_start_date, analysis_end_date
  ) %>% 
  distinct()

detections <- bind_rows(
  glider_detections,
  towed_detections
) %>%
  transmute(
    species_group = theme,              # required
    recorder_id = id,                   # required, fkey -> recorders.id
    latitude,                           # required, decimal degrees
    longitude,                          # required, decimal degrees
    analysis_period_start_datetime,     # required, date+time
    analysis_period_end_datetime,       # optional
    analysis_period_effort_seconds,     # optional (can be computed from start/end datetimes?)
    species = species,                  # optional (only used for multi-species groups, e.g. beaked)
    presence                            # required, [y, m, n]
  )



# summary -----------------------------------------------------------------

tabyl(recorders, platform_type)
tabyl(analyses, species_group)
analyses %>% 
  filter(recorder_id %in% filter(recorders, platform_type == "towed")$id) %>% 
  tabyl(recorder_id, species_group)
tabyl(tracks, recorder_id, recorder_on_off)
tabyl(detections, species, species_group)


# export ------------------------------------------------------------------

# create template dirs
if (!dir.exists("data/templates/20210519-mobile/data")) {
  dir.create("data/templates/20210519-mobile/data", recursive = TRUE)
}

# delete existing files
if (length(list.files("data/templates/20210519-mobile/data")) > 0) {
  walk(list.files("data/templates/20210519-mobile/data", full.names = TRUE), unlink)
}

export_recorders <- bind_rows(
  recorders %>% 
    filter(platform_type == "slocum") %>% 
    sample_n(size = 3),
  recorders %>% 
    filter(id %in% c("NEFSC_GU1803", "NEFSC_HB1303", "NEFSC_HB1503"))
)

write_xlsx(list(recorders = export_recorders), path = "data/templates/20210519-mobile/recorders.xlsx")
for (recorder_id in export_recorders$id) {
  cat(recorder_id, "\n")
  write_xlsx(
    list(
      analyses = analyses %>% 
        filter(recorder_id == !!recorder_id) %>% 
        relocate(recorder_id) %>% 
        relocate(protocol_reference, .after = last_col()),
      detections = detections %>% 
        filter(recorder_id == !!recorder_id) %>% 
        relocate(recorder_id) %>% 
        mutate(
          across(c(analysis_period_start_datetime, analysis_period_end_datetime), ~ format(., "%m/%d/%Y %H:%M:%S"))
        ),
      track = tracks %>% 
        filter(recorder_id == !!recorder_id) %>% 
        mutate(datetime = format(datetime, "%m/%d/%Y %H:%M:%S"))
    ),
    path = glue("data/templates/20210519-mobile/data/{recorder_id}.xlsx")
  )
}

