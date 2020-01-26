library(tidyverse)
library(lubridate)
library(jsonlite)

df_csv <- read_csv(
  "~/Dropbox/Work/nefsc/transfers/20200113 - hansen pam dataset/Hansen Johnson - narw_pam_database.csv",
  col_types = cols(
    .default = col_character(),
    CHANNEL = col_double(),
    LATITUDE = col_double(),
    LONGITUDE = col_double(),
    WATER_DEPTH_METERS = col_double(),
    RECORDER_DEPTH_METERS = col_double(),
    SAMPLING_RATE_HZ = col_double(),
    ANALYSIS_PERIOD_EFFORT_SECONDS = col_double(),
    N_VALIDATED_DETECTIONS = col_double(),
    MONITORING_DURATION = col_double()
  )) %>% 
  janitor::clean_names()

glimpse(df_csv)

table(df_csv$instrument_type)
table(df_csv$platform_type)
table(df_csv$narw_presence)

df_csv %>% 
  filter(platform_type == "slocum") %>% View()

df_csv %>% 
  filter(
    project == "2014-09-02_slocum_we10"
  ) %>% 
  arrange(analysis_period_start_datetime) %>% 
  nrow()

df_csv %>% 
  filter(
    project == "2014-09-02_slocum_we10"
  ) %>% 
  group_by(analysis_date) %>% 
  summarise(
    narw_presence = case_when(
      any(narw_presence == "detected") ~ "detected",
      any(narw_presence == "possible") ~ "possible",
      any(narw_presence == "undetected") ~ "undetected",
      TRUE ~ "unknown"
    )
  )

df_csv %>% 
  filter(
    project == "2016-04-13_slocum_we03"
  ) %>% 
  arrange(analysis_period_start_datetime) %>% 
  ggplot(aes(longitude, latitude, xend = lag(longitude), yend = lag(latitude))) +
  geom_segment() +
  geom_point(aes(color = narw_presence))

df_csv %>% 
  filter(
    project == "2016-04-13_slocum_we03"
  ) %>% 
  pull(analysis_date) %>% 
  unique() %>% 
  length()

df_csv %>% 
  filter(platform_type == "slocum") %>% 
  select(project, platform_id) %>% 
  distinct() %>% 
  arrange(project)


# gliders -----------------------------------------------------------------

df <- df_csv %>% 
  filter(platform_type == "slocum") %>% 
  mutate(analysis_date = ymd(analysis_date))

# compute median lat/lon by project,analysis_date
df_day <- df %>% 
  group_by(project, site_id, platform_type, analysis_date) %>% 
  summarise(
    latitude = median(latitude, na.rm = TRUE),
    longitude = median(longitude, na.rm = TRUE),
    narw_presence = case_when(
      any(narw_presence == "detected") ~ "detected",
      any(narw_presence == "possible") ~ "possible",
      any(narw_presence == "undetected") ~ "undetected",
      TRUE ~ "unknown"
    )
  ) %>% 
  ungroup() %>% 
  arrange(project, site_id, analysis_date) %>% 
  group_by(project, site_id) %>% 
  mutate(
    next_latitude = lead(latitude),
    next_longitude = lead(longitude),
  ) %>% 
  ungroup()

df_day %>% 
  ggplot(aes(longitude, latitude, xend = next_longitude, yend = next_latitude)) +
  geom_segment()

# time gaps
df_day %>% 
  group_by(project) %>% 
  mutate(
    diff_day = c(NA, diff(analysis_date))
  ) %>% 
  filter(diff_day > 1)


# export ------------------------------------------------------------------

x <- readRDS("rds/dataset.rds")

setdiff(names(df), names(x$deployments))
setdiff(names(x$deployments), names(df))

df_glider_deployments <- df %>% 
  select(names(x$deployments)) %>% 
  mutate(
    latitude = NA,
    longitude = NA
  ) %>% 
  distinct()

stopifnot(all(!duplicated(df_glider_deployments$project)))

df_glider_detections <- df_day %>% 
  transmute(
    project,
    platform_type,
    date = analysis_date,
    latitude,
    longitude,
    species = "narw",
    detection = case_when(
      narw_presence == "detected" ~ "yes",
      narw_presence == "possible" ~ "maybe",
      narw_presence == "undetected" ~ "no",
      TRUE ~ "unknown"
    )
  ) %>% 
  filter(!is.na(latitude), !is.na(longitude))
stopifnot(all(df_glider_detections$detection %in% c("yes", "no", "maybe")))
stopifnot(all(!is.na(df_glider_detections[, c("latitude", "longitude")])))

df_gliders <- df_glider_deployments %>% 
  left_join(
    df_glider_detections %>% 
      arrange(project) %>% 
      nest(data = -project),
    by = c("project")
  )
write_json(df_gliders, path = "../public/data/gliders.json", force = TRUE, pretty = TRUE)

