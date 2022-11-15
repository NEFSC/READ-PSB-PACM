library(tidyverse)
library(lubridate)
library(janitor)
library(glue)
library(sf)

source("src/functions.R")

detections_rds <- read_rds("data/datasets/moored/detections.rds")
deployments_rds <- read_rds("data/datasets/moored/deployments.rds")

# missing latitude/longitude
deployments_rds %>% 
  filter(is.na(latitude) | is.na(longitude)) %>% 
  distinct(id)

deployments_rds <- deployments_rds %>% 
  filter(!is.na(latitude) | !is.na(longitude))

detections_rds <- detections_rds %>% 
  filter(id %in% unique(deployments_rds$id))

# analysis period ---------------------------------------------------------
# TODO: add analysis_start_date, analysis_end_date, analyzed to deployments metadata table

analysis_periods <- detections_rds %>% 
  filter(id %in% deployments_rds$id) %>% 
  group_by(id) %>% 
  summarise(
    analysis_start_date = min(date),
    analysis_end_date = max(date),
    .groups = "drop"
  ) %>% 
  mutate(
    analyzed = TRUE
  )

deployments_analysis <- deployments_rds %>% 
  filter(!is.na(latitude)) %>% 
  left_join(analysis_periods, by = "id")

# qaqc: analysis period ---------------------------------------------------

# analysis periods vary by species
detections_rds %>%
  group_by(theme, id) %>%
  summarise(
    analysis_start_date = min(date),
    analysis_end_date = max(date),
    .groups = "drop"
  ) %>%
  group_by(id, analysis_start_date, analysis_end_date) %>%
  summarise(
    species = str_c(theme, collapse = ","),
    .groups = "drop"
  ) %>%
  add_count(id) %>%
  filter(n > 1) %>%
  arrange(id, analysis_start_date) %>%
  select(-n) %>%
  write_csv("data/qaqc/moored-varying-analysis-periods.csv")

# analysis period does not match monitoring period
analysis_periods %>%
  full_join(
    deployments_analysis %>%
      distinct(id, platform_type, monitoring_start_datetime, monitoring_end_datetime),
    by = "id"
  ) %>%
  mutate(
    same_start = analysis_start_date == as_date(monitoring_start_datetime),
    same_end = analysis_end_date == as_date(monitoring_end_datetime),
    difference_start_days = as.numeric(difftime(analysis_start_date, as_date(monitoring_start_datetime), units = "day")),
    difference_end_days = as.numeric(difftime(as_date(monitoring_end_datetime), analysis_end_date, units = "day")),
    monitoring_start_datetime = format(monitoring_start_datetime, "%Y-%m-%d %H:%M"),
    monitoring_end_datetime = format(monitoring_end_datetime, "%Y-%m-%d %H:%M")
  ) %>%
  select(id, platform_type, starts_with("monitoring"), starts_with("analysis"), starts_with("difference"), starts_with("same")) %>%
  arrange(id) %>%
  # filter(!same_start | !same_end) %>% view
  write_csv("data/qaqc/moored-analysis-periods.csv")


# fill: missing detections ------------------------------------------------
# presence = na for any date missing within the analysis period

# dates over analysis period of each deployment
deployments_dates <- deployments_analysis %>% 
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

# fill missing detection days with presence = na
# and add empty locations
detections <- deployments_dates %>%  
  select(theme, id, date) %>% 
  full_join(
    detections_rds,
    by = c("theme", "id", "date")
  ) %>% 
  mutate(
    presence = ordered(coalesce(presence, "na"), levels = c(levels(presence), "na")),
    locations = map(theme, ~ NULL)
  )


# qaqc: detections --------------------------------------------------------

# no detections are outside the deployment analysis period
stopifnot(
  detections_rds %>%
    anti_join(deployments_dates, by = c("theme", "id", "date")) %>% 
    nrow() == 0
)

# deployment monitoring days with no detection data (filled with presence = na)
deployments_dates %>% 
  anti_join(detections_rds, by = c("id", "date")) %>% 
  distinct(theme, id, start, end, date) %>% 
  select(theme, id = id, analysis_start_date = start, analysis_end_date = end, date) %>%
  arrange(theme, id, analysis_start_date, date) %>%
  write_csv("data/qaqc/moored-missing-dates.csv")
  # tabyl(id, theme)

# none of the deployments are all NA
stopifnot(
  detections %>% 
    count(theme, id, presence) %>% 
    pivot_wider(names_from = "presence", values_from = "n", values_fill = 0) %>% 
    mutate(total = n + na + y + m) %>% 
    filter(na == total) %>% 
    nrow() == 0
)


# summary -----------------------------------------------------------------

tabyl(detections_rds, theme, presence) # before fill
tabyl(detections, theme, presence)     # after fill


# deployments geom --------------------------------------------------------

# no missing id, latitude, longitude
stopifnot(
  all(
    deployments_analysis %>% 
      distinct(id, latitude, longitude) %>% 
      complete.cases()
  )
)

deployments_sf <- deployments_analysis %>% 
  distinct(id, latitude, longitude) %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

mapview::mapview(deployments_sf, legend = FALSE)

deployments <- deployments_sf %>% 
  left_join(deployments_analysis, by = "id") %>% 
  mutate(deployment_type = "stationary") %>% 
  relocate(deployment_type, geometry, .after = last_col())


# qaqc --------------------------------------------------------------------

qaqc_dataset(deployments, detections)


# export ------------------------------------------------------------------

list(
  deployments = deployments,
  detections = detections
) %>% 
  write_rds("data/datasets/moored.rds")

