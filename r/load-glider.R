# load glider dataset

library(tidyverse)
library(lubridate)
library(sf)

FILE_META <- "~/Dropbox/Work/nefsc/transfers/20200806 - glider data/Glider_metadata_2020-08-06.csv"
FILE_DETECT <- "~/Dropbox/Work/nefsc/transfers/20200804 - mooring and glider data/Glider_detection_data_2020-08-04.csv"


# load metadata -----------------------------------------------------------

df_projects_csv <- read_csv(
  FILE_META,
  col_types = cols(
    .default = col_character(),
    CHANNEL = col_integer(),
    WATER_DEPTH_METERS = col_double(),
    RECORDER_DEPTH_METERS = col_double(),
    SAMPLING_RATE_HZ = col_double()
  )
) %>% 
  janitor::clean_names()

df_projects <- df_projects_csv %>% 
  mutate(
    dataset = "glider",
    submission_date = ymd(submission_date),
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime),
    latitude = NA_real_,
    longitude = NA_real_
  ) %>% 
  select(dataset, id = unique_id, everything())

df_projects_species <- df_projects %>% 
  rename_with(
    ~ str_replace(., "_", ":"),
    starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
  ) %>%
  pivot_longer(
    starts_with(c("narw", "humpback", "sei", "fin", "blue")),
    names_to = c("species", ".value"),
    names_sep = ":",
    values_drop_na = TRUE
  ) %>%
  select(dataset, species, id, everything())

# load detect data --------------------------------------------------------

df_detects_csv <- read_csv(
  FILE_DETECT,
  col_types = cols(
    .default = col_character(),
    ANALYSIS_PERIOD_EFFORT_SECONDS = col_double(),
    LATITUDE = col_double(),
    LONGITUDE = col_double()
  )
) %>% 
  janitor::clean_names()

df_detects_raw <- df_detects_csv %>% 
  mutate(
    dataset = "glider",
    analysis_period_start_datetime = ymd_hms(analysis_period_start_datetime),
    analysis_period_end_datetime = ymd_hms(analysis_period_end_datetime)
  ) %>% 
  select(
    dataset, id = unique_id, analysis_period_effort_seconds, starts_with("analysis_period_"),
    latitude, longitude,
    starts_with("narw_"), starts_with("humpback_"), starts_with("sei_"), starts_with("fin_"), starts_with("blue_")
  ) %>%
  rename_with(
    ~ str_replace(., "_", ":"),
    starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
  ) %>% 
  pivot_longer(
    starts_with(c("narw", "humpback", "sei", "fin", "blue")),
    names_to = c("species", ".value"),
    names_sep = ":",
    values_drop_na = TRUE
  ) %>% 
  filter(!is.na(presence))


# generate tracks ---------------------------------------------------------

df_tracks <- df_detects_raw %>% 
  select(dataset, id, datetime = analysis_period_start_datetime, latitude, longitude) %>% 
  distinct() %>% 
  arrange(id, datetime)

sf_tracks_points <- df_tracks %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

sf_tracks <- sf_tracks_points %>% 
  group_by(dataset, id) %>% 
  summarise(
    start = min(datetime),
    end = max(datetime),
    do_union = FALSE
  ) %>% 
  st_cast("LINESTRING")

mapview::mapview(sf_tracks)


# generate daily detects --------------------------------------------------
# daily mean lat/lon of instantaneous detections

df_detects <- df_detects_raw %>% 
  filter(presence == "Detected") %>% 
  mutate(date = as_date(analysis_period_start_datetime)) %>% 
  arrange(id, species, date) %>% 
  group_by(dataset, id, species, date) %>% 
  summarise(
    n_detections = n(),
    latitude = first(latitude),
    longitude = first(longitude),
    .groups = "drop"
  ) %>% 
  mutate(
    presence = "y"
  ) %>% 
  select(dataset, species, id, date, presence, latitude, longitude)


# generate points ---------------------------------------------------------
# 
# df_points <- df_tracks %>% 
#   mutate(
#     point = str_c(project, format(as_date(datetime), "%Y%m%d"), sep = "_")
#   ) %>% 
#   arrange(point, datetime) %>% 
#   group_by(point, dataset, project) %>% 
#   summarise(
#     latitude = first(latitude),
#     longitude = first(longitude),
#     .groups = "drop"
#   ) %>% 
#   filter(
#     point %in% unique(df_detects_daily$point)
#   )
# 
# stopifnot(all(!duplicated(df_points$point)))
# 
# sf_points <- df_points %>% 
#   st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
# 
# mapview::mapview(sf_points)


# generate detects --------------------------------------------------------
# 
# df_detects <- df_detects_daily %>% 
#   select(-latitude, -longitude, -n_detections) %>% 
#   select(dataset, species, project, point, everything())


# qaqc --------------------------------------------------------------------
# 
# stopifnot(exprs = {
#   # no duplicated ids
#   all(!duplicated(df_projects$project))
#   
#   # require columns
#   all(!is.na(df_projects$project))
#   all(!is.na(select(df_projects, starts_with("data_poc"))))
#   all(!is.na(df_projects$instrument_type))
#   all(!is.na(select(df_projects, starts_with("submitter_"))))
#   all(!is.na(df_projects$submission_date))
#   
#   all(!is.na(df_detects$point))
#   all(!is.na(df_detects$project))
#   all(!is.na(df_detects$species))
#   all(!is.na(df_detects$presence))
#   all(!is.na(df_detects$date))
#   all(!is.na(df_detects$dataset))
#   
#   # enumerated values
#   all(df_projects$platform_type %in% c("slocum", "wave"))
#   all(unique(df_detects$presence) %in% c("y", "m", "n"))
#   
#   # no duplicate detect dates
#   all(
#     df_detects %>% 
#       group_by(point, species, date) %>% 
#       count() %>% 
#       pull(n) == 1
#   )
#   
#   # monitoring period end is after start
#   all(as.numeric(difftime(df_projects$monitoring_end_datetime, df_projects$monitoring_start_datetime, units = "sec")) > 0)
#   # latitude between 0 to 90
#   all(df_points$latitude >= 0)
#   all(df_points$latitude <= 90)
#   # latitude between -90 and 0 (west of central meridian)
#   all(df_points$longitude >= -90)
#   all(df_points$longitude <= 0)
#   
#   # meta and detect contain same ids
#   identical(sort(unique(df_projects$project)), sort(unique(df_detects$project)))
# })
# 
# 
# # meta summary ------------------------------------------------------------
# 
# # unique values
# janitor::tabyl(df_projects$platform_type)
# janitor::tabyl(df_projects$instrument_type)
# janitor::tabyl(df_projects$channel)
# janitor::tabyl(df_projects$soundfiles_timezone)
# janitor::tabyl(df_projects$duty_cycle_seconds)
# janitor::tabyl(df_projects$qc_data)
# 
# # timestamps
# df_projects %>% 
#   select(where(is.Date)) %>%
#   table()
# df_projects %>% 
#   select(where(is.POSIXct)) %>%
#   summary()
# 
# # numeric values
# df_projects %>% 
#   select(where(is.numeric)) %>%
#   summary()
# 
# # detection methods
# df_projects_species %>% 
#   janitor::tabyl(detection_method, species)
# 
# # protocol reference
# df_projects_species %>% 
#   janitor::tabyl(protocol_reference, detection_method, species)
# 
# 
# # detect summary ----------------------------------------------------------
# 
# df_detects %>% 
#   select(where(is.Date)) %>%
#   summary()
# 
# df_detects %>% 
#   janitor::tabyl(presence, species) %>% 
#   janitor::adorn_totals(where = c("row"))
# 
# df_detects %>% 
#   janitor::tabyl(presence, species) %>% 
#   janitor::adorn_percentages("row") %>% 
#   janitor::adorn_pct_formatting(digits = 0)
# 

# export ------------------------------------------------------------------

list(
  projects = df_projects,
  # points = sf_points,
  tracks = sf_tracks,
  detects = df_detects
) %>% 
  saveRDS("rds/glider.rds")

