library(tidyverse)
library(lubridate)
library(sf)

detections <- read_rds("data/moored/detections.rds")
deployments <- read_rds("data/moored/deployments.rds")


# fill missing lat/lon ----------------------------------------------------

deployments_BERCHOK_SAMANA_200901 <- deployments %>%
  filter(str_starts(id, "BERCHOK_SAMANA_200901_CH"), theme == "narw", !is.na(latitude)) %>% 
  select(id, project, site_id, latitude, longitude)

deployments <- deployments %>% 
  mutate(
    latitude = if_else(id == "BERCHOK_SAMANA_200901_CH1_1", median(deployments_BERCHOK_SAMANA_200901$latitude), latitude),
    longitude = if_else(id == "BERCHOK_SAMANA_200901_CH1_1", median(deployments_BERCHOK_SAMANA_200901$longitude), longitude)
  )

# stations ----------------------------------------------------------------

stations <- deployments %>% 
  select(id, latitude, longitude) %>% 
  distinct()

stopifnot(all(!duplicated(stations$id)))
stopifnot(all(!is.na(stations$latitude)))
stopifnot(all(!is.na(stations$longitude)))

sf_stations <- stations %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

mapview::mapview(sf_stations, legend = FALSE)

deployments_geom <- sf_stations %>% 
  left_join(deployments, by = "id") %>% 
  mutate(deployment_type = "station") %>% 
  relocate(deployment_type, geometry, .after = last_col())

# export ------------------------------------------------------------------

list(
  deployments = deployments_geom,
  detections = detections
) %>% 
  write_rds("data/moored.rds")
