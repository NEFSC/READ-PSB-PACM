# generate datasets

library(tidyverse)
library(lubridate)
library(sf)
library(glue)
library(jsonlite)

moored <- readRDS("rds/moored.rds")
glider <- readRDS("rds/glider.rds")
# towed <- readRDS("rds/towed.rds")

df_platform_types <- tribble(
  ~platform_type_id, ~platform_type,
  1, "mooring",
  2, "buoy",
  3, "slocum",
  4, "wave",
  5, "towed"
)
df_species <- tribble(
  ~species_id, ~species, ~species_label,
  1, "narw", "North Atlantic Right Whale",
  2, "sei", "Sei Whale",
  3, "blue", "Blue Whale",
  4, "humpback", "Humpback Whale",
  5, "fin", "Fin Whale",
  6, "beaked", "Beaked Whales",
  7, "kogia", "Kogia Whales"
)

identical(sort(names(moored$projects)), sort(names(glider$projects)))
df_projects <- bind_rows(
  moored$projects,
  glider$projects
  # towed$meta
) %>% 
  mutate(
    project_id = 1:n()
  ) %>% 
  left_join(df_platform_types, by = "platform_type") %>%
  select(project_id, project, everything())
df_projects %>% 
  janitor::tabyl(dataset, species)

identical(sort(names(moored$points)), sort(names(glider$points)))
sf_points <- bind_rows(
  moored$points,
  glider$points
  # towed$points
) %>% 
  mutate(
    point_id = 1:n()
  ) %>% 
  left_join(
    select(df_projects, dataset, project, project_id),
    by = c("dataset", "project")
  ) %>% 
  mutate(id = point_id) %>% 
  select(id, point_id, point, dataset, project_id, project, everything())
sf_points %>% 
  as_tibble() %>% 
  janitor::tabyl(dataset)

identical(sort(names(moored$detects)), sort(names(glider$detects)))
df_detects <- bind_rows(
  moored$detects,
  glider$detects
  # towed$detects
) %>%  
  left_join( 
    select(as_tibble(sf_points), point, point_id, project_id),
    by = c("point")
  ) %>% 
  left_join(
    select(df_projects, project_id, platform_type_id),
    by = "project_id"
  ) %>% 
  left_join(
    select(df_species, species_id, species),
    by = "species"
  )
df_detects %>% 
  janitor::tabyl(dataset, species)
df_detects %>% 
  janitor::tabyl(species, presence, dataset)

# identical(sort(names(glider$tracks)), sort(names(towed$tracks)))
sf_tracks <- bind_rows(
  glider$tracks
  # towed$tracks
) %>% 
  left_join(
    select(df_projects, project, project_id),
    by = "project"
  ) %>% 
  mutate(id = project_id)
sf_tracks %>% 
  as_tibble() %>% 
  janitor::tabyl(dataset)

# export: all -------------------------------------------------------------

df_projects %>% 
  write_csv(path = file.path("../public/data/all/", "projects.csv"), na = "")

df_detects %>% 
  select(point_id, date, species_id, presence) %>% 
  write_csv(path = file.path("../public/data/all/", "detects.csv"), na = "")

if (file.exists("../public/data/all/tracks.json")) {
  unlink("../public/data/all/tracks.json")
}
sf_tracks %>% 
  write_sf("../public/data/all/tracks.json", driver = "GeoJSON", layer_options = "ID_FIELD=id")

if (file.exists("../public/data/all/points.json")) {
  unlink("../public/data/all/points.json")
}
sf_points %>% 
  write_sf("../public/data/all/points.json", driver = "GeoJSON", layer_options = "ID_FIELD=id")

df_species %>% 
  select(id = species_id, label = species_label) %>% 
  write_json(df_species, "../src/assets/species.json", pretty = TRUE)


setdiff(sort(names(moored$projects)), sort(names(towed$projects)))
identical(sort(names(glider$meta)), sort(names(towed$meta)))

df_projects <- bind_rows(
  moored$meta,
  glider$meta,
  towed$meta
)

df_projects %>% 
  janitor::tabyl(species)

# datasets:
# - narw
# - sei
# - blue
# - humpback
# - beaked
# - kogia

# /data
#   geojson
#     gliders.geojson
#     moored.geojson
#     towed.geojson
#   themes
#     narw
#       theme.json
#       detect.csv
#     sei
#       theme.json
#       detect.csv
#     blue
#       theme.json
#       detect.csv
#     humpback
#       theme.json
#       detect.csv
#     beaked
#       theme.json
#       detect.csv
#     kogia
#       theme.json
#       detect.csv
#   meta.csv


# themes ------------------------------------------------------------------

df_themes <- tribble(
  ~id, ~label, ~moored, ~gliders, ~towed,
  "narw", "North Atlantic Right Whale", TRUE, TRUE, FALSE,
  "sei", "Sei Whale", TRUE, TRUE, FALSE,
  "blue", "Blue Whale", TRUE, TRUE, FALSE,
  "humpback", "Humpback Whale", TRUE, TRUE, FALSE,
  "beaked", "Beaked Whales", FALSE, FALSE, TRUE,
  "kogia",  "Kogia Whales", FALSE, FALSE, TRUE
)

write_json(df_themes, "../src/assets/themes.json", pretty = TRUE)

# meta --------------------------------------------------------------------

df_meta <- bind_rows(
  moored$meta %>% 
    mutate(dataset = "moored"),
  glider$meta %>% 
    mutate(dataset = "glider"),
  towed$meta %>% 
    mutate(dataset = "towed"),
) %>% 
  mutate(
    
  ) %>% 
  rename(id = unique_id) %>% 
  select(dataset, id, everything())

stopifnot(all(!duplicated(str_c(df_meta$unique_id, df_meta$species))))
 
df_meta %>% 
  janitor::tabyl(platform_type, dataset)
df_meta %>% 
  janitor::tabyl(species, dataset)

df_meta %>% 
  write_csv(path = file.path("../public/data/", "projects.csv"), na = "")


# glider tracks -----------------------------------------------------------

glider_detects <- glider$detect %>% 
  select()

glider_tracks <- glider$detect %>% 
  mutate(
    datetime = analysis_period_start_datetime + seconds(analysis_period_effort_seconds / 2)
  ) %>% 
  select(id = unique_id, datetime, latitude, longitude) %>% 
  distinct() %>% 
  arrange(id, datetime)

sf_glider_tracks_pnt <- glider_tracks %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

sf_glider_tracks_line <- sf_glider_tracks_pnt %>% 
  group_by(id) %>% 
  summarise(
    start = min(datetime),
    end = max(datetime),
    do_union = FALSE
  ) %>% 
  st_cast("LINESTRING")

plot(sf_glider_tracks_line)
mapview::mapview(sf_glider_tracks_line)

if (file.exists("../public/data/tracks/glider.json")) {
  unlink("../public/data/tracks/glider.json")
}
sf_glider_tracks_line %>% 
  write_sf("../public/data/tracks/glider.json", driver = "GeoJSON", layer_options = "ID_FIELD=id")


# towed tracks ------------------------------------------------------------

tracks_towed <- towed$tracks %>% 
  select(id = unique_id, datetime, latitude, longitude) %>% 
  distinct() %>% 
  arrange(id, datetime)

sf_tracks_towed_pnt <- tracks_towed %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

sf_tracks_towed_line <- sf_tracks_towed_pnt %>% 
  group_by(id) %>% 
  summarise(
    start = min(datetime),
    end = max(datetime),
    do_union = FALSE
  ) %>% 
  st_cast("LINESTRING")

plot(sf_tracks_towed_line)
mapview::mapview(sf_tracks_towed_line)

if (file.exists("../public/data/tracks/towed.json")) {
  unlink("../public/data/tracks/towed.json")
}
sf_tracks_towed_line %>% 
  write_sf("../public/data/tracks/towed.json", driver = "GeoJSON", layer_options = "ID_FIELD=id")


# moored stations ---------------------------------------------------------

df_moored_stn <- moored$meta %>% 
  select(id = unique_id, latitude, longitude) %>% 
  distinct()

stopifnot(all(!duplicated(df_moored_stn$id)))

df_moored_stn_pnt <- df_moored_stn %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

mapview::mapview(df_moored_stn_pnt)

if (file.exists("../public/data/tracks/moored.json")) {
  unlink("../public/data/tracks/moored.json")
}
df_moored_stn_pnt %>% 
  write_sf("../public/data/tracks/moored.json", driver = "GeoJSON", layer_options = "ID_FIELD=id")

# narw --------------------------------------------------------------------

glider$detect

narw_detect <- df_detect %>% 
  filter(species == "narw") %>% 
  select(-species)
narw <- list(
  id = "narw",
  detections = bind_rows(
    moored$detect %>% 
      filter(species == "narw"),
    hansen$glider$detections %>% 
      filter(species == "narw"),
    hansen$buoy$detections %>% 
      filter(species == "narw")
  ) %>% 
    select(-species),
  projects = bind_rows(
    moored$meta %>% 
      filter(species == "narw"),
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