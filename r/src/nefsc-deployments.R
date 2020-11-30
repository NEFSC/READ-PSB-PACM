# nefsc-deployments theme (no detections)

library(tidyverse)
library(lubridate)
library(sf)

moored <- read_rds("data/moored.rds")

df_deployments <- moored$deployments %>% 
  filter(
    data_poc_affiliation == "NOAA NEFSC"
  ) %>% 
  mutate(
    theme = "nefsc-deployments",
    detection_method = NA_character_,
    protocol_reference = NA_character_
  ) %>% 
  distinct(.keep_all = TRUE)

stopifnot(all(!duplicated(df_deployments$id)))

df_detections <- moored$detections %>% 
  filter(
    deployment_id %in% df_deployments$id
  ) %>% 
  mutate(
    theme = "nefsc-deployments"
  ) %>% 
  distinct(theme, deployment_id, date) %>% 
  mutate(
    species = NA_character_,
    presence = "na",
    call_type = NA_character_
  )

list(
  deployments = df_deployments,
  detections = df_detections
) %>% 
  write_rds("data/nefsc-deployments.rds")
