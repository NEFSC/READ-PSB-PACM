library(tidyverse)
library(lubridate)
library(glue)
library(sf)

detections <- read_rds("data/towed/detections.rds")
deployments <- read_rds("data/towed/deployments.rds")
tracks <- read_rds("data/towed/tracks.rds")$sf

# deployments ----------------------------------------------------------------

deployments_geom <- tracks %>% 
  select(-start, -end) %>% 
  left_join(deployments, by = c("deployment_id" = "id")) %>% 
  rename(id = deployment_id) %>% 
  mutate(deployment_type = "track") %>% 
  relocate(deployment_type, geometry, .after = last_col()) %>% 
  relocate(theme)

# export ------------------------------------------------------------------

list(
  deployments = deployments_geom,
  detections = detections
) %>% 
  write_rds("data/towed.rds")
