# export datasets to web app

library(tidyverse)
library(lubridate)
library(sf)
library(glue)
library(jsonlite)

towed <- readRDS("data/towed.rds")
moored <- readRDS("data/moored.rds")
glider <- readRDS("data/glider.rds")

# setdiff(names(towed$deployments), names(glider$deployments))
# setdiff(names(glider$deployments), names(towed$deployments))
# setdiff(names(moored$deployments), names(towed$deployments))

df_deployments <- bind_rows(
  towed$deployments,
  glider$deployments,
  moored$deployments
)

# mapview::mapview(df_deployments, zcol = "deployment_type")

# setdiff(names(towed$detections), names(glider$detections))
# setdiff(names(glider$detections), names(towed$detections))
# setdiff(names(moored$detections), names(towed$detections))
# setdiff(names(towed$detections), names(moored$detections))

df_detections <- bind_rows(
  towed$detections,
  glider$detections,
  moored$detections
)


theme <- "narw"

export_theme <- function (theme) {
  x_detections <- df_detections %>% 
    filter(theme == !!theme) %>% 
    select(-theme)
  
  x_deployments <- df_deployments %>% 
    filter(theme == !!theme) %>% 
    select(-theme)
  
  
  missing_detections <- setdiff(x_deployments$id, unique(x_detections$deployment_id))
  if (length(missing_detections) > 0) {
    warning(glue("Found {length(missing_detections)} deployments without any detections ({str_c(missing_detections, collapse = ', ')}), removing from deployments table"))
    x_deployments <- x_deployments %>% 
      filter(!id %in% missing_detections)
  }
  
  x_stations <- x_deployments %>% 
    filter(deployment_type == "station") %>% 
    select(id)
  x_tracks <- x_deployments %>% 
    filter(deployment_type == "track") %>% 
    select(id)
  
  missing_deployments <- setdiff(unique(x_detections$deployment_id), x_deployments$id)
  if (length(missing_deployments) > 0) {
    warning(glue("Missing {length(missing_deployments)} deployments found in detections ({str_c(missing_deployments, collapse = ', ')}), removing detections"))
    x_detections <- x_detections %>% 
      filter(!id %in% missing_deployments)
  }
  
  missing_stations <- setdiff(
    x_deployments %>% 
      filter(deployment_type == "station") %>% 
      pull(id),
    x_stations$id
  )
  if (length(missing_stations) > 0) {
    warning(glue("Missing {length(missing_stations)} stations found in deployments ({str_c(missing_stations, collapse = ', ')}), doing nothing"))
  }
  
  missing_tracks <- setdiff(
    x_deployments %>% 
      filter(deployment_type == "track") %>% 
      pull(id),
    x_tracks$id
  )
  if (length(missing_tracks) > 0) {
    warning(glue("Missing {length(missing_tracks)} tracks found in deployments ({str_c(missing_tracks, collapse = ', ')}), doing nothing"))
  }
  
  x_detections %>% 
    relocate(locations, .after = last_col()) %>%
    mutate(
      locations = map_chr(locations, toJSON, null = 'null')
    ) %>%
    rename(id = deployment_id) %>% 
    write_csv(file.path("../public/data/", theme, "detections.csv"), na = "")
  
  if (file.exists(file.path("../public/data/", theme, "deployments.json"))) {
    unlink(file.path("../public/data/", theme, "deployments.json"))
  }
  x_deployments %>%
    mutate_at(vars(monitoring_start_datetime, monitoring_end_datetime, submission_date), format_ISO8601) %>% 
    write_sf(file.path("../public/data/", theme, "deployments.json"), driver = "GeoJSON", layer_options = "ID_FIELD=id")
}

export_theme("narw")
export_theme("fin")
export_theme("blue")
export_theme("humpback")
export_theme("sei")
export_theme("beaked")
export_theme("kogia")
export_theme("sperm")