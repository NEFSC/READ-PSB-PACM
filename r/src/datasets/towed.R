library(tidyverse)
library(lubridate)
library(glue)
library(janitor)
library(sf)

detections <- read_rds("data/datasets/towed/detections.rds")$daily
deployments <- read_rds("data/datasets/towed/deployments.rds")
tracks <- read_rds("data/datasets/towed/tracks.rds")$sf

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
stopifnot(
  detections %>%
    anti_join(deployments_dates, by = c("theme", "id", "date")) %>% 
    nrow() == 0
)

# analyzed deployment monitoring days with no detection data (add rows with presence="n")
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

detections_fill %>% 
  distinct(theme, id, date, presence) %>% 
  left_join(
    deployments %>%
      select(theme, id, analyzed),
    by = c("theme", "id")
  ) %>%
  # filter(analyzed) %>% 
  janitor::tabyl(id, presence, theme) %>% 
  janitor::adorn_totals(where = c("row", "col"))

deployments_dates %>% 
  count(id)

janitor::tabyl(deployments, id, analyzed, theme)

detections_fill %>% 
  filter(presence == "n") %>% 
  janitor::tabyl(id, theme)

# detections_fill %>% 
#   filter(id == "NEFSC_HB1603", theme == "beaked") %>% 
#   mutate(n_locations = map_int(locations, ~ if_else(is_null(.x), 0L, nrow(.x)))) %>% 
#   select(-locations) %>% 
#   View


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
  write_rds("data/datasets/towed.rds")
