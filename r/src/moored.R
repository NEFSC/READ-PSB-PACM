library(tidyverse)
library(lubridate)
library(sf)

detections <- read_rds("data/moored/detections.rds")
deployments <- read_rds("data/moored/deployments.rds")


# export analysis period based on detection data --------------------------

# TODO: add analysis_start/end_date, analyzed to deployments metadata
analysis_periods <- detections %>% 
  group_by(id) %>% 
  summarise(
    analysis_start_date = min(date),
    analysis_end_date = max(date),
    .groups = "drop"
  )

# varying analysis periods by species
# detections %>%
#   group_by(theme, id) %>%
#   summarise(
#     analysis_start_date = min(date),
#     analysis_end_date = max(date),
#     .groups = "drop"
#   ) %>%
#   group_by(id, analysis_start_date, analysis_end_date) %>%
#   summarise(
#     species = str_c(theme, collapse = ",")
#   ) %>%
#   add_count(id) %>%
#   filter(n > 1) %>%
#   arrange(id, analysis_start_date) %>%
#   select(-n) %>%
#   write_csv("~/moored-varying-analysis-periods.csv")

deployments <- deployments %>% 
  left_join(analysis_periods, by = "id") %>% 
  mutate(analyzed = TRUE)

# generate analysis periods table for Gen
analysis_periods %>%
  full_join(
    deployments %>%
      distinct(id, monitoring_start_datetime, monitoring_end_datetime),
    by = "id"
  ) %>%
  mutate(
    same_start = analysis_start_date == as_date(monitoring_start_datetime),
    same_end = analysis_end_date == as_date(monitoring_end_datetime),
    monitoring_start_datetime = format(monitoring_start_datetime, "%Y-%m-%d %H:%M"),
    monitoring_end_datetime = format(monitoring_end_datetime, "%Y-%m-%d %H:%M")
  ) %>%
  select(id, starts_with("monitoring"), starts_with("analysis"), starts_with("same")) %>%
  arrange(id) %>%
  write_csv("~/moored-analysis-periods.csv")


# fill missing lat/lon ----------------------------------------------------

# TODO: fix BERCHOK_SAMANA_200901_CH* missing lat/lon
deployments_BERCHOK_SAMANA_200901 <- deployments %>%
  filter(str_starts(id, "BERCHOK_SAMANA_200901_CH"), theme == "narw", !is.na(latitude)) %>% 
  select(id, project, site_id, latitude, longitude)

deployments <- deployments %>% 
  mutate(
    latitude = if_else(id == "BERCHOK_SAMANA_200901_CH1_1", median(deployments_BERCHOK_SAMANA_200901$latitude), latitude),
    longitude = if_else(id == "BERCHOK_SAMANA_200901_CH1_1", median(deployments_BERCHOK_SAMANA_200901$longitude), longitude)
  )


# fill missing detection days ---------------------------------------------
# for any date within the analysis period (analysis_start/end_date)
# if no value in detection, then set presence=na

deployments_dates <- deployments %>% 
  transmute(
    theme,
    id,
    start = analysis_start_date, 
    end = analysis_end_date,
    n_day = as.numeric(difftime(end, start, unit = "day"))
  ) %>%
  rowwise() %>% 
  mutate(
    date = list(seq.Date(start, end, by = "day"))
  ) %>% 
  unnest(date)

# detections that are outside the deployment analysis period
detections %>%
  anti_join(deployments_dates, by = c("theme", "id", "date"))

# deployment monitoring days with no detection data (add rows with presence="na")
deployments_dates %>% 
  anti_join(detections, by = c("id", "date")) %>% 
  distinct(theme, id, start, end, date) %>% 
  select(theme, id = id, analysis_start_date = start, analysis_end_date = end, date) %>%
  arrange(theme, id, analysis_start_date, date) %>%
  write_csv("~/moored-missing-dates.csv")
  tabyl(id, theme)

# deployments %>%
#   filter(id == "NEFSC_NE_OFFSHORE_201604_WAT_OC_02_WAT_OC")

detections %>% 
  janitor::tabyl(id, theme)

detections_fill <- deployments_dates %>%  
  select(theme, id, date) %>% 
  full_join(
    detections,
    by = c("theme", "id", "date")
  ) %>% 
  mutate(
    presence = ordered(coalesce(presence, "na"), levels = c(levels(presence), "na"))
  )
janitor::tabyl(detections, theme, presence)
janitor::tabyl(detections_fill, theme, presence)

janitor::tabyl(detections, id, theme)
janitor::tabyl(detections_fill, id, theme)

detections_fill %>% 
  count(theme, id, presence) %>% 
  pivot_wider(names_from = "presence", values_from = "n", values_fill = 0) %>% 
  mutate(total = n + na + y + m) %>% 
  filter(na == total)

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
  mutate(deployment_type = "fixed") %>% 
  relocate(deployment_type, geometry, .after = last_col())

# export ------------------------------------------------------------------

list(
  deployments = deployments_geom,
  detections = detections_fill
) %>% 
  write_rds("data/moored.rds")

