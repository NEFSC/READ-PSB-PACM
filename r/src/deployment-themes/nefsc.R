# deployments/nefsc theme

library(tidyverse)
library(lubridate)
library(sf)

files <- config::get("files")

source("src/functions.R")

# only used for analysis period
moored <- read_rds("data/datasets/moored.rds")


# load -----------------------------------------------------------

df_csv <- read_csv(
  file.path(files$root, files$moored$metadata),
  col_types = cols(.default = col_character())
) %>% 
  janitor::clean_names() %>% 
  filter(!is.na(project)) %>% 
  mutate(
    unique_id = coalesce(unique_id, paste0(project, "_", site_id)),
    platform_type = if_else(
      str_starts(project, "NEFSC_MA-RI_202211"),
      coalesce(platform_type, "mooring"),
      platform_type
    )
  )

df_deployments <- df_csv %>% 
  filter(data_poc_affiliation == "NOAA NEFSC", !is.na(latitude)) %>% 
  transmute(
    theme = "deployments-nefsc",
    id = unique_id,
    project,
    site_id,
    latitude = parse_number(latitude),
    longitude = parse_number(longitude),

    monitoring_start_datetime = mdy_hm(monitoring_start_datetime),
    monitoring_end_datetime = mdy_hm(monitoring_end_datetime),

    platform_type = fct_recode(platform_type, mooring = "Mooring"),
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
    submission_date = mdy(submission_date),

    # species specific
    detection_method = NA_character_,
    protocol_reference = NA_character_,
    call_type = NA_character_
  )

# add geom ----------------------------------------------------------------

stations <- df_deployments %>% 
  filter(!is.na(latitude)) %>% 
  select(id, latitude, longitude) %>% 
  distinct()

sf_stations <- stations %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

deployments <- sf_stations %>% 
  full_join(df_deployments, by = "id") %>% 
  mutate(deployment_type = "stationary") %>% 
  relocate(deployment_type, geometry, .after = last_col())


# detections --------------------------------------------------------------

detections <- df_deployments %>% 
  filter(!is.na(monitoring_end_datetime)) %>% 
  distinct(theme, id, monitoring_start_datetime, monitoring_end_datetime) %>% 
  left_join(
    moored$deployments %>% 
      filter(analyzed) %>% 
      as_tibble() %>% 
      select(id, analysis_start_date, analysis_end_date) %>% 
      distinct(),
    by = "id"
  ) %>% 
  mutate(
    start = coalesce(analysis_start_date, as_date(monitoring_start_datetime)),
    end = coalesce(analysis_end_date, as_date(monitoring_end_datetime))
  ) %>% 
  select(theme, id, start, end) %>% 
  rowwise() %>% 
  mutate(
    date = list(seq.Date(start, end, by = "day"))
  ) %>% 
  unnest(date) %>% 
  select(-start, -end) %>% 
  mutate(
    species = NA_character_,
    presence = "d",
    locations = map(id, ~ NULL)
  )


# qaqc --------------------------------------------------------------------

qaqc_dataset(deployments, detections)

stopifnot(all(!duplicated(stations$id)))
stopifnot(all(!is.na(stations$latitude)))
stopifnot(all(!is.na(stations$longitude)))

mapview::mapview(sf_stations, legend = FALSE)

stopifnot(all(!duplicated(deployments$id)))
stopifnot(identical(df_deployments$id, deployments$id))


# export ------------------------------------------------------------------

list(
  deployments = deployments,
  detections = detections
) %>% 
  write_rds("data/deployment-themes/nefsc.rds")
