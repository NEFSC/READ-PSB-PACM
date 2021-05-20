library(tidyverse)
library(lubridate)
library(glue)
library(sf)

detections <- read_rds("data/glider/detections.rds")$daily
deployments <- read_rds("data/glider/deployments.rds")
tracks <- read_rds("data/glider/tracks.rds")$sf


# remove wave -------------------------------------------------------------

deployments <- deployments %>% 
  filter(platform_type != "wave")

detections <- detections %>% 
  filter(id %in% unique(deployments$id))


# export analysis period based on detection data --------------------------

# TODO: add analysis start/end date to deployments metadata
analysis_periods <- detections %>%
  group_by(id) %>%
  summarise(
    analysis_start_date = min(date),
    analysis_end_date = max(date),
    .groups = "drop"
  )

deployments <- deployments %>% 
  left_join(analysis_periods, by = "id") %>% 
  mutate(analyzed = TRUE)

# analysis periods are the same for each species
stopifnot(detections %>%
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
  nrow() == 0)

# analysis periods
# same_start/end=TRUE indicates where analysis period (based on detections)
# does not match start or end of monitoring period
analysis_periods %>%
  full_join(
    deployments %>%
      distinct(id, monitoring_start_datetime, monitoring_end_datetime),
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
  select(id, starts_with("monitoring"), starts_with("analysis"), starts_with("difference"), starts_with("same")) %>%
  arrange(id) %>% 
  # filter(!same_start | !same_end) %>% View
  write_csv("data/qaqc/glider-analysis-periods.csv")


# exclude deployments with no detections per species ----------------------

# deployments with no detections by species
deployments %>% 
  anti_join(
    detections %>% 
      distinct(id, theme),
    by = c("id", "theme")
  ) %>%
  # tabyl(theme)
  write_csv("data/qaqc/glider-deployments-without-detections.csv")
# all blue

# exclude deployments with no data for each species (unable to tell from metadata table)
deployments <- deployments %>% 
  semi_join(
    detections %>% 
      distinct(id, theme),
    by = c("id", "theme")
  )
tabyl(deployments, id, theme)


# fill missing detection days ---------------------------------------------
# since only include detected or possibly, do not fill with NA

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

# detections that are outside the deployment analysis period (none)
stopifnot(
  detections %>%
    anti_join(deployments_dates, by = c("theme", "id", "date")) %>% 
    nrow() == 0
)

# deployment monitoring days with no detection data (add rows with presence="na")
deployments_dates %>% 
  anti_join(detections, by = c("id", "date")) %>% 
  distinct(theme, id, start, end, date) %>% 
  select(theme, id = id, analysis_start_date = start, analysis_end_date = end, date) %>%
  arrange(theme, id, analysis_start_date, date) %>%
  write_csv("data/qaqc/glider-missing-dates.csv")
  # tabyl(id, theme)

detections_fill <- deployments_dates %>%
  select(theme, id, date) %>%
  full_join(
    detections,
    by = c("theme", "id", "date")
  ) %>%
  mutate(
    presence = ordered(coalesce(presence, "na"), levels = c("y", "m", "n", "na"))
  )
janitor::tabyl(detections, theme, presence)
janitor::tabyl(detections_fill, theme, presence)

janitor::tabyl(detections, id, theme)
janitor::tabyl(detections_fill, id, theme)

# none of the deployments are all NA
stopifnot(
  detections_fill %>% 
    count(theme, id, presence) %>% 
    pivot_wider(names_from = "presence", values_from = "n", values_fill = 0) %>% 
    mutate(total = n + na + y + m) %>% 
    filter(na == total) %>% 
    nrow() == 0
)


# deployments ----------------------------------------------------------------

deployments_geom <- tracks %>% 
  select(-start, -end) %>% 
  left_join(deployments, by = c("id")) %>% 
  mutate(deployment_type = "mobile") %>% 
  relocate(deployment_type, geometry, .after = last_col()) %>% 
  relocate(theme)


# export ------------------------------------------------------------------

list(
  deployments = deployments_geom,
  detections = detections_fill
) %>% 
  write_rds("data/glider.rds")
