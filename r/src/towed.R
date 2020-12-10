library(tidyverse)
library(lubridate)
library(glue)
library(sf)

detections <- read_rds("data/towed/detections.rds")
deployments <- read_rds("data/towed/deployments.rds")
tracks <- read_rds("data/towed/tracks.rds")$sf


# add 2017 kogia ----------------------------------------------------------

kogia_2017 <- deployments %>% 
  filter(id == "NEFSC_HRS1701") %>% 
  mutate(theme = "kogia")

deployments <- bind_rows(deployments, kogia_2017) %>% 
  arrange(theme, id)

# fill missing detection days ---------------------------------------------

deployments_dates <- deployments %>% 
  as_tibble() %>% 
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

# deployment monitoring days with no detection data (add rows with presence="na")
deployments_dates %>% 
  anti_join(detections, by = c("deployment_id", "date"))

detections %>% 
  janitor::tabyl(deployment_id, theme)
deployments %>% 
  janitor::tabyl(id, theme)

detections_fill <- deployments_dates %>%  
  select(theme, deployment_id, date) %>% 
  full_join(
    detections,
    by = c("theme", "deployment_id", "date")
  ) %>% 
  mutate(
    presence = ordered(coalesce(presence, "na"), levels = c("y", "m", "n", "na"))
    # species = if_else(theme == "beaked", coalesce(species, "N/A"), coalesce(species, theme))
  )
janitor::tabyl(detections, theme, species)
janitor::tabyl(detections_fill, theme, species)
janitor::tabyl(detections, theme, presence)
janitor::tabyl(detections_fill, theme, presence)

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
  detections = detections_fill
) %>% 
  write_rds("data/towed.rds")
