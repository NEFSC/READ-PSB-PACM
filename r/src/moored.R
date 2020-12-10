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


# fill missing detection days ---------------------------------------------

deployments_dates <- deployments %>% 
  transmute(
    theme,
    deployment_id = id,
    start = as_date(monitoring_start_datetime), 
    end = as_date(monitoring_end_datetime),
    n_day = as.numeric(difftime(end, start, unit = "day"))
  ) %>%
  rowwise() %>% 
  mutate(
    date = list(seq.Date(start, end, by = "day"))
  ) %>% 
  unnest(date)

# detections that are outside the deployment monitoring period
detections %>%
  anti_join(deployments_dates, by = c("theme", "deployment_id", "date"))

detections %>%
  anti_join(deployments_dates, by = c("theme", "deployment_id", "date")) %>% 
  # tabyl(deployment_id)
  filter(deployment_id == "WHOI_GOM_201810_mdr1018_buoy") %>% 
  summary()

deployments %>% 
  filter(id == "WHOI_GOM_201810_mdr1018_buoy")

# deployment monitoring days with no detection data (add rows with presence="na")
deployments_dates %>% 
  anti_join(detections, by = c("deployment_id", "date")) %>% 
  tabyl(deployment_id)

deployments %>% 
  filter(id == "NEFSC_NE_OFFSHORE_201604_WAT_OC_02_WAT_OC")


detections %>% 
  janitor::tabyl(deployment_id, species)

detections_fill <- deployments_dates %>%  
  select(theme, deployment_id, date) %>% 
  full_join(
    detections,
    by = c("theme", "deployment_id", "date")
  ) %>% 
  mutate(
    presence = ordered(coalesce(presence, "na"), levels = c(levels(presence), "na")),
    species = coalesce(species, theme)
  )
janitor::tabyl(detections, theme, species)
janitor::tabyl(detections_fill, theme, species)
janitor::tabyl(detections, theme, presence)
janitor::tabyl(detections_fill, theme, presence)

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
  detections = detections_fill
) %>% 
  write_rds("data/moored.rds")
