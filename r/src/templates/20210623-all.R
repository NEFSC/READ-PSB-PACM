# mobile template

# NOTES
#   - How to determine which recorders/deployments should have analyzed=FALSE for a given species/theme?
#   - How to determine analysis_period_start/end_date for towed arrays since they do not include detections with presence=0? use monitoring period?
#   - How to distinguish between not detected and not analyzed for towed arrays? Need cruise dates, or to generate daily detected/not detected before uploading.
#   - Beaked whale species is a little problematic. When extracting analysis periods from detection data, I get different start/ends for each beaked species.
#     Addressing this by having a pre-defined list of beaked whale species so they can be grouped by species=Beaked.
#   - Lat/lon position for gliders requires joining detections table to gps data (tracks) by datetime, which is not robust.
#     Better to include lat/lon directly in detections table. Estimating location by interpolating tracks for towed arrays (gliders have matching datetimes).
#   - How to guarantee stationary data (moored, buoy) are daily?

# PACM_TEMPLATE_DETECTION_DATA.xlsx
#   - ANALYSIS_PERIOD_START_DATETIME and ANALYSIS_PERIOD_END_DATETIME datetime formats needed to be standardized
#   - ANALYSIS_PROTOCOL_REFERENCE should be PROTOCOL_REFERENCE
#   - ANALYSIS_SAMPLING_RATE_Hz should be ANALYSIS_SAMPLING_RATE_HZ (capital Z)
#   - CALL_TYPE, DETECTION_METHOD, PROTOCOL_REFERENCE, ANALYSIS_SAMPLING_RATE_HZ must be constant for each {UNIQUE_ID, SPECIES}
#   - CALL_TYPE contains NA and "20Hz pulse" for UNIQUE_ID="WHOI_SBNMS_202003_sbnms0320_we04" and SPECIES="Fin"
#   - SPECIES must be enumerated (only contain allowable values, currently contains "fin" and "Fin")
#   - PRESENCE must be enumerated (only contain allowable values, currently uses 0, 1, 2 but instructions say "Detected", "Possibly Detected", "Not Detected" or "NA")
# PACM_TEMPLATE_GPS_DATA.xlsx
#   - DATETIME format needed to be standardized
# PACM_TEMPLATE_METADATA.xlsx
#   - PLATFORM_TYPE must be enumerated (only contain allowable values)

# enum columns:
#   detections: species, presence
#   metadata: platform_type
# repeated columns (same value for all detections per unique_id+species)
#   detections: call_type, detection_method, protocol_reference, analysis_sampling_rate_hz, qc_processing

library(tidyverse)
library(lubridate)
library(sf)
library(glue)
library(janitor)
library(readxl)

beaked_species <- c("Cuvier's", "Gervais'/True's", "Sowerby's", "True's")

config_files <- config::get("files")

themes <- read_rds("data/themes.rds")

# load --------------------------------------------------------------------

root_dir <- file.path(config_files$root, "..", "templates", "20210623-all")
df_metadata_raw <- read_excel(file.path(root_dir, "PACM_TEMPLATE_METADATA.xlsx"), sheet = 1) %>% 
  clean_names()
df_tracks_raw <- read_excel(file.path(root_dir, "PACM_TEMPLATE_GPS_DATA.xlsx"), sheet = 1) %>% 
  clean_names()
df_detections_raw <- read_excel(file.path(root_dir, "PACM_TEMPLATE_DETECTION_DATA.xlsx"), sheet = 1) %>% 
  clean_names()


# analyses ----------------------------------------------------------------

# create analysis dataset from detections by {theme,id}
# start/end dates based on start/end of detection data
df_analyses <- df_detections_raw %>% 
  transmute(
    id = unique_id, 
    theme = case_when(
      species == "fin" ~ "Fin", # fix Fin/fin
      species %in% beaked_species ~ "Beaked", # group beaked whales into theme=beaked
      TRUE ~ species
    ),
    theme = tolower(theme),
    analyzed = TRUE,
    call_type = case_when(
      id == "WHOI_SBNMS_202003_sbnms0320_we04" & theme == "fin" ~ "20Hz pulse",
      TRUE ~ call_type
    ), 
    detection_method, 
    protocol_reference = analysis_protocol_reference,
    analysis_sampling_rate_hz,
    analysis_period_start_date = as_date(analysis_period_start_datetime),
    analysis_period_end_date  = coalesce(as_date(analysis_period_end_datetime), analysis_period_start_date)
  ) %>%
  group_by(theme, id, analyzed, call_type, detection_method, protocol_reference, analysis_sampling_rate_hz) %>% 
  summarise(
    analysis_start_date = min(analysis_period_start_date),
    analysis_end_date = max(analysis_period_end_date),
    .groups = "drop"
  )

df_analyses
tabyl(df_analyses, theme)

stopifnot(
  df_analyses %>% 
    add_count(theme, id) %>% 
    filter(n > 1) %>% 
    nrow() == 0
)

# daily timseries (just dates) for each {theme,id}
df_analyses_dates <- df_analyses %>% 
  select(theme, id, analysis_start_date, analysis_end_date) %>% 
  rowwise() %>% 
  mutate(date = list(seq.Date(analysis_start_date, analysis_end_date, by = "day"))) %>% 
  unnest(date) %>% 
  select(theme, id, date)
df_analyses_dates

# metadata ----------------------------------------------------------------

names(themes$deployments)
# theme
# deployment_type

# id
# project
# site_id
# latitude
# longitude
# monitoring_start_datetime
# monitoring_end_datetime
# platform_type
# platform_id
# water_depth_meters
# recorder_depth_meters
# instrument_type
# instrument_id
# sampling_rate_hz
# soundfiles_timezone
# duty_cycle_seconds
# channel
# qc_data
# data_poc_name
# data_poc_affiliation
# data_poc_email
# submitter_name
# submitter_affiliation
# submitter_email
# submission_date

# analyzed
# call_type
# detection_method
# protocol_reference
# analysis_start_date
# analysis_end_date
# analysis_sampling_rate_hz

# geometry

df_metadata <- df_metadata_raw %>% 
  transmute(
    id = unique_id,
    project,
    site_id,
    latitude,
    longitude,
    monitoring_start_datetime,
    monitoring_end_datetime,
    platform_type = tolower(platform_type),
    platform_id,
    water_depth_meters,
    recorder_depth_meters,
    instrument_type,
    instrument_id,
    sampling_rate_hz,
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
    submission_date,
    
    deployment_type = case_when(
      platform_type %in% c("mooring", "buoy") ~ "stationary",
      platform_type %in% c("slocum", "wave", "towed") ~ "mobile",
      TRUE ~ NA_character_
    )
  )

stopifnot(all(!is.na(select(df_metadata, id, platform_type, deployment_type))))
tabyl(df_metadata, platform_type, deployment_type)

df_metadata_mobile <- df_metadata %>% 
  filter(deployment_type == "mobile")

df_metadata_stationary <- df_metadata %>% 
  filter(deployment_type == "stationary")


# tracks ------------------------------------------------------------------

df_tracks <- df_tracks_raw %>% 
  rename(id = unique_id)

sf_tracks_points <- df_tracks %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

sf_mobile <- sf_tracks_points %>% 
  group_by(id) %>% 
  summarise(
    do_union = FALSE,
    .groups = "drop"
  ) %>% 
  st_cast("LINESTRING")

mapview::mapview(sf_mobile, legend = FALSE)


# stations ----------------------------------------------------------------

stopifnot(all(!is.na(select(df_metadata_stationary, id, latitude, longitude))))

sf_stationary <- df_metadata_stationary %>% 
  select(id, latitude, longitude) %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

mapview::mapview(sf_stationary, legend = FALSE)


# recorders -------------------------------------------------------------
# recorder = metadata + geometry

sf_recorders_stationary <- sf_stationary %>% 
  left_join(df_metadata_stationary, by = "id")

sf_recorders_mobile <- sf_mobile %>% 
  left_join(df_metadata_mobile, by = "id")

sf_recorders <- bind_rows(
  sf_recorders_stationary,
  sf_recorders_mobile
) %>% 
  relocate(geometry, .after = last_col())


# deployments -------------------------------------------------------------
# deployment = recorder + analyses metadata

names(sf_recorders)
names(df_analyses)

sf_deployments <- sf_recorders %>% 
  full_join(df_analyses, by = "id") %>% 
  relocate(theme) %>% 
  relocate(geometry, .after = last_col())
  
stopifnot(identical(sort(setdiff(names(themes$deployments), "analysis_sampling_rate")), sort(names(sf_deployments))))

df_deployments <- sf_deployments %>% 
  as_tibble() %>% 
  select(-geometry)

summary(df_deployments)
view(df_deployments)

tabyl(df_deployments, analyzed)
tabyl(df_deployments, id, theme)


# detections: stationary ---------------------------------------------------------

stationary_ids <- df_deployments %>% 
  filter(deployment_type == "stationary") %>% 
  pull(id)

df_detections_all <- df_detections_raw %>% 
  rename(id = unique_id) %>% 
  transmute(
    theme = case_when(
      species == "fin" ~ "Fin",
      species %in% beaked_species ~ "Beaked",
      TRUE ~ species
    ),
    theme = tolower(theme),
    id,
    species = case_when(
      theme == "beaked" ~ species,
      TRUE ~ species
    ),
    analysis_period_start_datetime,
    analysis_period_end_datetime,
    analysis_period_effort_seconds,
    presence
  )
tabyl(df_detections_all, species, theme)

# stationary: daily values
df_detections_stationary <- df_detections_all %>% 
  filter(id %in% stationary_ids) %>% 
  transmute(
    theme,
    id,
    species,
    date = as_date(analysis_period_start_datetime),
    presence = presence
  )

# no duplicate dates
stopifnot(
  df_detections_stationary %>% 
    group_by(theme, id, date, species) %>% 
    add_count() %>% 
    filter(n > 1) %>% 
    nrow() == 0
)


# detections: glider ------------------------------------------------------
# only first location per day

interpolate_track <- function(detections, track) {
  detections$latitude <- approx(track$datetime, track$latitude, xout = detections$analysis_period_start_datetime, rule = 1)$y
  detections$longitude <- approx(track$datetime, track$longitude, xout = detections$analysis_period_start_datetime, rule = 1)$y
  detections
}

glider_ids <- df_deployments %>% 
  filter(platform_type == "slocum") %>% 
  pull(id)

df_detections_gliders_interpolate <- df_detections_all %>% 
  filter(id %in% glider_ids) %>% 
  nest(detections = c(analysis_period_start_datetime, analysis_period_end_datetime, analysis_period_effort_seconds, presence)) %>% 
  left_join(
    df_tracks %>% 
      nest(track = c(datetime, latitude, longitude)),
    by = "id"
  ) %>% 
  rowwise() %>% 
  mutate(
    detections = list(interpolate_track(detections, track))
  )

head(df_detections_gliders_interpolate$track[[1]], 100) %>% 
  ggplot(aes(longitude, latitude)) +
  geom_path() +
  geom_point(size = 3) +
  geom_point(
    data = head(df_detections_gliders_interpolate$detections[[1]], 100),
    aes(color = factor(presence))
  )

df_detections_gliders <- df_detections_gliders_interpolate %>% 
  select(-track) %>% 
  unnest(detections) %>% 
  mutate(date = as_date(analysis_period_start_datetime)) %>%
  nest(locations = c(analysis_period_start_datetime, analysis_period_end_datetime, analysis_period_effort_seconds, latitude, longitude, presence)) %>%
  rowwise() %>%
  mutate(
    presence = max(locations$presence),
    locations = list(
      locations %>% 
        arrange(desc(presence)) %>% 
        filter(presence > 0) %>% 
        slice(1L)
    )
    # n_locations = nrow(locations)
  ) %>% 
  relocate(locations, .after = last_col()) %>%
  full_join(
    df_analyses_dates %>% 
      filter(id %in% glider_ids),
    by = c("theme", "id", "date")
  ) %>% 
  arrange(theme, id, date, species)

# tabyl(df_detections_gliders, n_locations, presence)


# detections: towed -------------------------------------------------------
# all locations per day

towed_ids <- df_deployments %>% 
  filter(platform_type == "towed") %>% 
  pull(id)

df_detections_towed_interpolate <- df_detections_all %>% 
  filter(id %in% towed_ids) %>%
  nest(detections = c(analysis_period_start_datetime, analysis_period_end_datetime, analysis_period_effort_seconds, presence)) %>% 
  left_join(
    df_tracks %>% 
      nest(track = c(datetime, latitude, longitude)),
    by = "id"
  ) %>% 
  rowwise() %>% 
  mutate(
    detections = list(interpolate_track(detections, track))
  )

head(df_detections_towed_interpolate$track[[1]], 100) %>% 
  ggplot(aes(longitude, latitude)) +
  geom_path() +
  geom_point(size = 3) +
  geom_point(
    data = head(df_detections_towed_interpolate$detections[[1]], 100),
    aes(color = factor(presence))
  )

df_detections_towed <- df_detections_towed_interpolate %>% 
  select(-track) %>% 
  unnest(detections) %>% 
  mutate(date = as_date(analysis_period_start_datetime)) %>%
  nest(locations = c(analysis_period_start_datetime, analysis_period_end_datetime, analysis_period_effort_seconds, latitude, longitude, presence)) %>%
  rowwise() %>%
  mutate(
    presence = max(locations$presence),
    locations = list(
      locations %>% 
        arrange(desc(presence)) %>% 
        filter(presence > 0)
    )
    # n_locations = nrow(locations)
  ) %>% 
  relocate(locations, .after = last_col()) %>% 
  full_join(
    df_analyses_dates %>% 
      filter(id %in% towed_ids),
    by = c("theme", "id", "date")
  ) %>% 
  arrange(theme, id, date, species)

# tabyl(df_detections_towed, n_locations, presence)


# detections --------------------------------------------------------------

df_detections <- bind_rows(
  df_detections_stationary,
  df_detections_gliders,
  df_detections_towed
)

stopifnot(identical(sort(names(themes$detections)), sort(names(df_detections))))


# export ------------------------------------------------------------------

# sf_deployments -> deployments.json
# df_detections -> detections.csv

tabyl(df_deployments, call_type, theme)
tabyl(df_deployments, qc_data, theme)
tabyl(df_detections, species, theme)
tabyl(df_detections, presence, theme)

# create template dirs
if (!dir.exists("data/templates/20210623-all")) {
  dir.create("data/templates/20210623-all", recursive = TRUE)
}

# delete existing files
if (length(list.files("data/templates/20210623-all")) > 0) {
  walk(list.files("data/templates/20210623-all", full.names = TRUE), unlink)
}

df_deployments %>% 
  write_csv(file.path("data/templates/20210623-all", "web-deployments.csv"), na = "")
df_detections %>%
  select(-locations) %>% 
  write_csv(file.path("data/templates/20210623-all", "web-detections.csv"), na = "")
