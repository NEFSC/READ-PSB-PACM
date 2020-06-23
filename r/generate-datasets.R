# generate datasets by species/group

library(tidyverse)
library(lubridate)
library(glue)
library(jsonlite)

gen <- readRDS("rds/gen.rds")
hansen <- readRDS("rds/hansen.rds")
towed_arrays <- readRDS("rds/towed-arrays.rds")

# each dataset has:
# - tracks.json
# - deployments.csv
# - detections.csv

# datasets:
# - narw
# - sei
# - blue
# - humpback
# - beaked
# - kogia


# narw --------------------------------------------------------------------

narw <- list(
  id = "narw",
  detections = bind_rows(
    gen$detections %>% 
      filter(species == "narw"),
    hansen$glider$detections %>% 
      filter(species == "narw"),
    hansen$buoy$detections %>% 
      filter(species == "narw")
  ) %>% 
    select(-species),
  deployments = bind_rows(
    gen$deployments,
    hansen$glider$deployments,
    hansen$buoy$deployments
  ),
  tracks = hansen$glider$tracks
)

anti_join(
  narw$deployments,
  bind_rows(
    narw$detections,
    narw$tracks
  ),
  by = c("project", "site_id")
)


# sei ---------------------------------------------------------------------

sei <- list(
  id = "sei",
  detections = gen$detections %>% 
    filter(species == "sei") %>% 
    select(-species),
  deployments = gen$deployments,
  tracks = NULL
)
sei$deployments <- semi_join(
  sei$deployments,
  sei$detections,
  by = c("project", "site_id")
)


# blue ---------------------------------------------------------------------

blue <- list(
  id = "blue",
  detections = gen$detections %>% 
    filter(species == "blue") %>% 
    select(-species),
  deployments = gen$deployments,
  tracks = NULL
)
blue$deployments <- semi_join(
  blue$deployments,
  blue$detections,
  by = c("project", "site_id")
)


# humpback ---------------------------------------------------------------------

humpback <- list(
  id = "humpback",
  detections = gen$detections %>% 
    filter(species == "humpback") %>% 
    select(-species),
  deployments = gen$deployments,
  tracks = NULL
)
humpback$deployments <- semi_join(
  humpback$deployments,
  humpback$detections,
  by = c("project", "site_id")
)


# beaked ------------------------------------------------------------------

beaked <- list(
  id = "beaked",
  detections = towed_arrays$beaked %>% 
    filter(!is.na(utc), !is.na(latitude)) %>% 
    group_by(track_id, date = as_date(utc), species) %>% 
    slice(1) %>% 
    ungroup() %>% 
    transmute(
      project = track_id,
      site_id = NA_character_,
      platform_type = "towed_array",
      date,
      latitude,
      longitude,
      species,
      detection = "yes"
    ),
  deployments = towed_arrays$beaked %>%
    filter(!is.na(utc), !is.na(latitude)) %>%  
    group_by(track_id) %>% 
    summarise(
      monitoring_start_datetime = min(utc),
      monitoring_end_datetime = max(utc)
    ) %>% 
    transmute(
      project = track_id,
      data_poc_name = "",
      data_poc_affiliation = "",
      data_poc_email = "",
      platform_type = "towed_array",
      site_id = NA_character_,
      instrument_type = "",
      instrument_id = "",
      channel = NA_real_,
      submitter_name = "",
      submitter_affiliation = "",
      submitter_email = "",
      submission_date = "",
      latitude = NA_real_,
      longitude = NA_real_,
      water_depth_meters = NA_real_,
      recorder_depth_meters = NA_real_,
      soundfiles_timezone = "",
      sample_rate_hz = NA_real_,
      duty_cycle_seconds = NA_real_,
      monitoring_start_datetime,
      monitoring_end_datetime,
      qc_data = "",
      detection_method = "",
      protocol_reference = ""
    ),
  tracks = towed_arrays$tracks %>% 
    transmute(
      project = track_id,
      site_id = NA_character_,
      platform_type = "towed_array",
      date = utc,
      latitude,
      longitude
    )
)


# kogia ------------------------------------------------------------------

kogia <- list(
  id = "kogia",
  detections = towed_arrays$kogia %>% 
    filter(!is.na(utc), !is.na(latitude)) %>% 
    group_by(track_id, date = as_date(utc), click_type) %>% 
    slice(1) %>% 
    ungroup() %>% 
    transmute(
      project = track_id,
      site_id = NA_character_,
      platform_type = "towed_array",
      date,
      latitude,
      longitude,
      species = click_type,
      detection = "yes"
    ),
  deployments = towed_arrays$kogia %>% 
    filter(!is.na(utc), !is.na(latitude)) %>%  
    group_by(track_id) %>% 
    summarise(
      monitoring_start_datetime = min(utc),
      monitoring_end_datetime = max(utc)
    ) %>% 
    transmute(
      project = track_id,
      data_poc_name = "",
      data_poc_affiliation = "",
      data_poc_email = "",
      platform_type = "towed_array",
      site_id = NA_character_,
      instrument_type = "",
      instrument_id = "",
      channel = NA_real_,
      submitter_name = "",
      submitter_affiliation = "",
      submitter_email = "",
      submission_date = "",
      latitude = NA_real_,
      longitude = NA_real_,
      water_depth_meters = NA_real_,
      recorder_depth_meters = NA_real_,
      soundfiles_timezone = "",
      sample_rate_hz = NA_real_,
      duty_cycle_seconds = NA_real_,
      monitoring_start_datetime,
      monitoring_end_datetime,
      qc_data = "",
      detection_method = "",
      protocol_reference = ""
    ),
  tracks = towed_arrays$tracks %>% 
    transmute(
      project = track_id,
      site_id = NA_character_,
      platform_type = "towed_array",
      date = utc,
      latitude,
      longitude
    )
)

list(narw, sei, blue, humpback, beaked, kogia) %>% 
  walk(function (x) {
    cat(x$id, "\n")
    
    if (!dir.exists(file.path("../public/data/", x$id))) {
      cat(glue("creating: {file.path('../public/data/', x$id)}"), "\n")
      dir.create(file.path('../public/data/', x$id)) 
    }
    
    x$detections %>% 
      write_csv(path = file.path('../public/data/', x$id, "detections.csv"), na = "")
    x$deployments %>% 
      write_csv(path = file.path('../public/data/', x$id, "deployments.csv"), na = "")
    if (!is.null(x$tracks)) {
      x$tracks %>% 
        nest(data = -c(project, site_id, platform_type)) %>% 
        write_json(path = file.path('../public/data/', x$id, "tracks.json"), force = TRUE, pretty = TRUE)  
    } else {
      data.frame() %>% 
        write_json(path = file.path('../public/data/', x$id, "tracks.json"), force = TRUE, pretty = TRUE)  
    }
  })


list(narw, sei, blue, humpback, beaked, kogia) %>% 
  map_df(function (x) {
    x$detections
  }) %>% 
  pull(platform_type) %>% 
  table()