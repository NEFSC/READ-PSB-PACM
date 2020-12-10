library(tidyverse)
library(lubridate)
library(glue)
library(sf)

detections <- read_rds("data/glider/detections.rds")
deployments <- read_rds("data/glider/deployments.rds")
tracks <- read_rds("data/glider/tracks.rds")$sf

# fill missing detection days ---------------------------------------------
# since only include detected or possibly, do not fill with NA

# deployments_dates <- deployments %>% 
#   transmute(
#     theme,
#     deployment_id = id,
#     start = as_date(monitoring_start_datetime), 
#     end = as_date(monitoring_end_datetime),
#     n_day = as.numeric(difftime(end, start, unit = "day"))
#   ) %>%
#   rowwise() %>% 
#   mutate(
#     date = list(seq.Date(start, end, by = "day"))
#   ) %>% 
#   unnest(date)
# 
# # detections that are outside the deployment monitoring period
# detections %>%
#   anti_join(deployments_dates, by = c("theme", "deployment_id", "date"))
# 
# detections %>%
#   anti_join(deployments_dates, by = c("theme", "deployment_id", "date")) %>% 
#   # tabyl(deployment_id)
#   filter(deployment_id == "WHOI_GOM_201912_gom1219_we03") %>% 
#   summary()
# 
# deployments %>% 
#   filter(id == "WHOI_GOM_201912_gom1219_we03")
# 
# # deployment monitoring days with no detection data (add rows with presence="na")
# deployments_dates %>% 
#   anti_join(detections, by = c("deployment_id", "date")) %>% 
#   # tabyl(deployment_id)
#   filter(deployment_id == "WHOI_GOM_201812_gom1218_we03") %>% summary
# 
# deployments %>% 
#   filter(id == "NEFSC_NE_OFFSHORE_201604_WAT_OC_02_WAT_OC")
# 
# detections %>% 
#   janitor::tabyl(deployment_id, species)
# 
# detections_fill <- deployments_dates %>%  
#   select(theme, deployment_id, date) %>% 
#   full_join(
#     detections,
#     by = c("theme", "deployment_id", "date")
#   ) %>% 
#   mutate(
#     presence = ordered(coalesce(presence, "na"), levels = c("y", "m", "n", "na")),
#     species = coalesce(species, theme)
#   )
# janitor::tabyl(detections, theme, species)
# janitor::tabyl(detections_fill, theme, species)
# janitor::tabyl(detections, theme, presence)
# janitor::tabyl(detections_fill, theme, presence)

# deployments ----------------------------------------------------------------

# exclude deployments with no data for each species (unable to tell from metadata table)
deployments <- deployments %>% 
  semi_join(
    detections %>% 
      distinct(id = deployment_id, theme),
    by = c("id", "theme")
  )

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
  detections = detections %>% 
    filter(presence %in% c("y", "m"))
) %>% 
  write_rds("data/glider.rds")
