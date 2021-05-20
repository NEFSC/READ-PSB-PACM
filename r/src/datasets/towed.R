library(tidyverse)
library(lubridate)
library(janitor)
library(glue)
library(sf)

source("src/functions.R")

detections_rds <- read_rds("data/datasets/towed/detections.rds")$daily
deployments_rds <- read_rds("data/datasets/towed/deployments.rds")
tracks_rds <- read_rds("data/datasets/towed/tracks.rds")$sf


# fill missing detection days ---------------------------------------------

deployments_dates <- deployments_rds %>% 
  as_tibble() %>% 
  transmute(
    theme,
    id,
    analyzed,
    cruise_dates
  ) %>%
  unnest(cruise_dates) %>% 
  select(-leg)

# no detections outside deployment cruise dates
stopifnot(
  detections_rds %>%
    anti_join(deployments_dates, by = c("theme", "id", "date")) %>% 
    nrow() == 0
)

# deployment monitoring days with no detection data (fill with presence = n)
deployments_dates %>% 
  filter(analyzed) %>% 
  anti_join(detections_rds, by = c("id", "date")) %>%
  tabyl(id, theme)

detections <- deployments_dates %>%  
  left_join(
    detections_rds,
    by = c("theme", "id", "date")
  ) %>% 
  mutate(
    presence = if_else(analyzed, coalesce(presence, "n"), "na"),
    presence = as.character(presence)
  ) %>% 
  select(-analyzed)


# summary -----------------------------------------------------------------

tabyl(detections_rds, theme, presence)
tabyl(detections, theme, presence)

tabyl(deployments_rds, id, theme, analyzed)

detections %>% 
  distinct(theme, id, date, presence) %>% 
  left_join(
    deployments_rds %>%
      select(theme, id, analyzed),
    by = c("theme", "id")
  ) %>%
  filter(analyzed) %>% 
  tabyl(id, presence, theme) %>% 
  adorn_totals(where = c("row", "col"))

# number of days with presence = n
detections %>% 
  filter(presence == "n") %>% 
  tabyl(id, theme)


# deployments ----------------------------------------------------------------

# no missing tracks or tracks without metadata
stopifnot(identical(sort(tracks_rds$id), sort(unique(deployments_rds$id))))

deployments <- tracks_rds %>% 
  select(-start, -end) %>% 
  left_join(deployments_rds, by = c("id")) %>% 
  select(-cruise_dates) %>% 
  mutate(deployment_type = "mobile") %>% 
  relocate(deployment_type, geometry, .after = last_col()) %>% 
  relocate(theme)


# qaqc --------------------------------------------------------------------

qaqc_dataset(deployments, detections)


# export ------------------------------------------------------------------

list(
  deployments = deployments,
  detections = detections
) %>% 
  write_rds("data/datasets/towed.rds")
