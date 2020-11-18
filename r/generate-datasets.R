# generate datasets

library(tidyverse)
library(lubridate)
library(sf)
library(glue)
library(jsonlite)

# rm(list = ls())


towed <- readRDS("rds/towed.rds")
moored <- readRDS("rds/moored.rds")
glider <- readRDS("rds/glider.rds")

df_projects <- bind_rows(
  moored$projects,
  glider$projects
) %>% 
  rename_with(
    ~ str_replace(., "_", ":"),
    starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
  ) %>%
  pivot_longer(
    starts_with(c("narw", "humpback", "sei", "fin", "blue")),
    names_to = c("species", ".value"),
    names_sep = ":",
    values_drop_na = TRUE
  ) %>% 
  bind_rows(
    towed$projects
  ) %>% 
  select(dataset, species, id, everything())

df_detects <- bind_rows(
  moored$detects,
  glider$detects
) %>% 
  left_join(
    select(df_projects, id, species, platform_type),
    by = c("id", "species")
  ) %>% 
  select(species, id, date, presence, latitude, longitude, platform_type)

sf_tracks <- bind_rows(
  glider$tracks
) %>% 
  inner_join(
    select(df_projects, id, species),
    by = "id"
  )

stopifnot(identical(sort(unique(df_detects$id)), sort(unique(df_projects$id))))


export_theme <- function (x, theme) {
  x$detects %>% 
    write_csv(path = file.path("../public/data/", theme, "detections.csv"), na = "")

  x$deployments %>% 
    write_csv(path = file.path("../public/data/", theme, "deployments.csv"), na = "")
  
  if (file.exists(file.path("../public/data/", theme, "tracks.json"))) {
    unlink(file.path("../public/data/", theme, "tracks.json"))
  }
  x$tracks %>%
    write_sf(file.path("../public/data/", theme, "tracks.json"), driver = "GeoJSON", layer_options = "ID_FIELD=track_id")
  
  if (file.exists(file.path("../public/data/", theme, "stations.json"))) {
    unlink(file.path("../public/data/", theme, "stations.json"))
  }
  x$stations %>%
    write_sf(file.path("../public/data/", theme, "stations.json"), driver = "GeoJSON", layer_options = "ID_FIELD=station_id")
}

# THE RULES
# - detections > unique(d, date)
# - detections, deployments, tracks, and stations must contain the same set of id
# - stations
#   fixed: moored, buoy
#   mobile-daily: wave, slocum
#   mobile-detect: towed
# - files:
#   deployments: csv, unique(id), platform_type
#   detections: csv, unique(id, date), id -> deployments.id, presence, platform_type
#   stations: geojson, unique(id), properties.id -> deployments.id, properties.platform_type, station_type
#   tracks: geojson, unique(id), properties.id -> deployments.id, properties.platform_type

# towed -------------------------------------------------------------------


beaked_deployments <- towed$projects %>% 
  filter(species == "beaked")
beaked_detections_nested <- towed$detects %>% 
  select(species, id, date, latitude, longitude, presence, call_type, starts_with("analysis_")) %>% 
  filter(species == "beaked", id %in% beaked_deployments$id) %>% 
  nest(data = -c(species, id, date, call_type, presence)) %>% 
  arrange(species, id, date, call_type) %>% 
  mutate(
    detection_row = row_number() - 1
  )
beaked_stations <- beaked_detections_nested %>% 
  unnest(data) %>% 
  mutate(station_id = row_number()) %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
beaked_detections <- beaked_detections_nested %>% 
  select(-data) %>% 
  left_join(
    towed$projects %>% 
      select(species, id, platform_type),
    by = c("species", "id")
  )
beaked_tracks <- towed$tracks %>% 
  filter(id %in% beaked_deployments$id) %>% 
  mutate(track_id = row_number())

list(
  deployments = beaked_deployments,
  detects = beaked_detections,
  tracks = beaked_tracks,
  stations = beaked_stations
) %>% 
  export_theme(theme = "beaked")








beaked <- list(
  projects = towed$projects %>% 
    filter(species == "beaked"),
  tracks = towed$tracks,
  detects = towed$daily %>% 
    filter(species == "beaked")
)

# stopifnot(identical(sort(unique(beaked$tracks$id)), sort(unique(beaked$detects$id))))
beaked_projects <- intersect(intersect(unique(beaked$projects$id), unique(beaked$tracks$id)), unique(beaked$detects$id))
beaked$projects <- filter(beaked$projects, id %in% beaked_projects)
beaked$tracks <- filter(beaked$tracks, id %in% beaked_projects)
beaked$detects <- filter(beaked$detects, id %in% beaked_projects) %>% 
  arrange(id, date, call_type) %>% 
  mutate(row = row_number() - 1)

df_stations_beaked <- towed$detects %>% 
  filter(species == "beaked")

df_stations_beaked %>% 
  arrange(id, analysis_period_start) %>% 
  group_by(id, date) %>% 
  mutate(n = n()) %>% 
  filter(n > 1) %>% 
  View()

sf_stations_beaked <- df_stations_beaked %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>% 
  mutate(
    station_type = "mobile"
  ) %>% 
  arrange(id, analysis_period_start, call_type) %>% 
  mutate(station_id = row_number()) %>% 
  select(station_id, station_type, id, date, everything())

beaked$detects <- beaked$detects
beaked$stations <- sf_stations_beaked %>% 
  mutate_at(vars(analysis_period_start, analysis_period_end), ~ format(.x, "%Y-%m-%d %H:%M:%S")) %>% 
  left_join(
    beaked$detects %>% 
      select(id, date, call_type, idx),
    by = c("id", "date", "call_type")
  )


export_theme(beaked, "beaked")
mapview::mapview(beaked$stations)


beaked$stations %>% 
  write_sf(file.path("../public/data/beaked/points.json"), driver = "GeoJSON")

kogia <- list(
  projects = towed$projects %>% 
    filter(species == "kogia"),
  tracks = towed$tracks,
  detects = towed$detects %>% 
    filter(species == "kogia")
)

# stopifnot(identical(sort(unique(kogia$tracks$id)), sort(unique(kogia$detects$id))))
kogia_projects <- intersect(unique(kogia$projects$id), unique(kogia$detects$id))
kogia$projects <- filter(kogia$projects, id %in% kogia_projects)
kogia$tracks <- filter(kogia$tracks, id %in% kogia_projects)
kogia$detects <- filter(kogia$detects, id %in% kogia_projects)

export_theme(kogia, "kogia")

# narw --------------------------------------------------------------------

narw <- list(
  detects = df_detects %>% 
    filter(species == "narw"),
  projects = df_projects %>% 
    filter(species == "narw"),
  tracks = sf_tracks %>% 
    filter(species == "narw")
)

narw_projects <- intersect(unique(narw$projects$id), unique(narw$detects$id))
narw$projects <- filter(narw$projects, id %in% narw_projects)
narw$tracks <- filter(narw$tracks, id %in% narw_projects)
narw$detects <- filter(narw$detects, id %in% narw_projects)

export_theme(narw, "narw")

# export ------------------------------------------------------------------


list("narw", "sei", "blue", "humpback", "fin") %>% 
  walk(function (s) {
    cat(s, "\n")
    
    x <- list(
      detects = df_detects %>% 
        filter(species == s),
      projects = df_projects %>% 
        filter(species == s),
      tracks = sf_tracks %>% 
        filter(species == s)
    )
    
    x_projects <- intersect(unique(x$projects$id), unique(x$detects$id))
    x$projects <- filter(x$projects, id %in% x_projects)
    x$tracks <- filter(x$tracks, id %in% x_projects)
    x$detects <- filter(x$detects, id %in% x_projects)
    
    export_theme(x, s)
  })

