library(tidyverse)
library(lubridate)
library(glue)
library(sf)

detections <- read_rds("data/towed/detections.rds")
deployments <- read_rds("data/towed/deployments.rds")
tracks <- read_rds("data/towed/tracks.rds")$sf

# fill missing detection days ---------------------------------------------

deployments_dates <- deployments %>% 
  as_tibble() %>% 
  transmute(
    theme,
    id,
    analyzed,
    cruise_dates
  ) %>%
  unnest(cruise_dates) %>% 
  select(-leg)

# detections that are outside the deployment cruise dates
detections %>%
  anti_join(deployments_dates, by = c("theme", "id", "date"))

# analyzed deployment monitoring days with no detection data (add rows with presence="na")
deployments_dates %>% 
  filter(analyzed) %>% 
  anti_join(detections, by = c("id", "date")) %>%
  tabyl(id, theme)

deployments_dates %>% 
  janitor::tabyl(id, theme, analyzed)

detections_fill <- deployments_dates %>%  
  left_join(
    detections,
    by = c("theme", "id", "date")
  ) %>% 
  mutate(
    presence = if_else(analyzed, coalesce(presence, "n"), "na"),
    presence = as.character(presence)
    # species = if_else(theme == "beaked", coalesce(species, "N/A"), coalesce(species, theme))
  ) %>% 
  select(-analyzed)
janitor::tabyl(detections, theme, species)
janitor::tabyl(detections_fill, theme, species)
janitor::tabyl(detections, theme, presence)
janitor::tabyl(detections_fill, theme, presence)

janitor::tabyl(detections_fill, id, presence, theme)

janitor::tabyl(deployments, id, analyzed, theme)

# deployments ----------------------------------------------------------------

deployments_geom <- tracks %>% 
  select(-start, -end) %>% 
  left_join(deployments, by = c("id")) %>% 
  select(-cruise_dates) %>% 
  mutate(deployment_type = "mobile") %>% 
  relocate(deployment_type, geometry, .after = last_col()) %>% 
  relocate(theme)

# export ------------------------------------------------------------------

list(
  deployments = deployments_geom,
  detections = detections_fill
) %>% 
  write_rds("data/towed.rds")
