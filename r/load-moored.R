# load buoy/mooring dataset

library(tidyverse)
library(lubridate)
library(tsibble)
library(logger)

log_threshold(DEBUG)

FILE_META <- "~/Dropbox/Work/nefsc/transfers/20200804 - mooring and glider data/Moored_metadata_2020-08-04.csv"
FILE_DETECT <- "~/Dropbox/Work/nefsc/transfers/20200804 - mooring and glider data/Moored_detection_data_2020-08-04.csv"

# load projects -----------------------------------------------------------

df_projects_csv <- read_csv(
  FILE_META,
  col_types = cols(
    .default = col_character(),
    CHANNEL = col_integer(),
    LATITUDE = col_double(),
    LONGITUDE = col_double(),
    WATER_DEPTH_METERS = col_double(),
    RECORDER_DEPTH_METERS = col_double(),
    SAMPLING_RATE_HZ = col_double()
  )
) %>% 
  janitor::clean_names() # cleans up column names, mainly converting to lowercase

df_projects_all <- df_projects_csv %>%
  mutate(
    submission_date = ymd(submission_date),
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime),
    platform_type = fct_recode(
      platform_type,
      "mooring" = "Mooring",
      "buoy" = "surface buoy"
    ),
    dataset = "moored"
  ) %>% 
  rename(project_name = project) %>% 
  select(dataset, project = unique_id, everything())


# load detect data --------------------------------------------------------

df_detects_csv <- read_csv(
  FILE_DETECT,
  col_types = cols(
    .default = col_character(),
    ANALYSIS_PERIOD_EFFORT_SECONDS = col_double(),
    NARW_N_VALIDATED_DETECTIONS = col_integer()
  )
) %>% 
  janitor::clean_names()

df_detects_all <- df_detects_csv %>% 
  mutate(
    dataset = "moored",
    analysis_period_start_datetime = ymd_hms(analysis_period_start_datetime),
    analysis_period_end_datetime = ymd_hms(analysis_period_end_datetime)
  ) %>% 
  select(dataset, project = unique_id, everything())


# screen projects ---------------------------------------------------------

# only projects with detection data
projects_no_detections <- setdiff(unique(df_projects_all$project), unique(df_detects_all$project))
log_info("excluding projects with no detection data (n = {length(projects_no_detections)})")

# only projects with valid lat/lon
projects_invalid_latlon <- df_projects_all %>% 
  filter(is.na(latitude) | is.na(longitude)) %>% 
  pull(project)
log_info("excluding projects with invalid lat/lon (n = {length(projects_invalid_latlon)})")

df_projects <- df_projects_all %>% 
  filter(!project %in% c(projects_no_detections, projects_invalid_latlon))
  
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
  select(dataset, species, project, everything())

df_detects <- df_detects_all %>% 
  filter(project %in% df_projects$project) %>% 
  rename_with(
    ~ str_replace(., "_", ":"),
    starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
  ) %>% 
  pivot_longer(
    starts_with(c("narw", "humpback", "sei", "fin", "blue")),
    names_to = c("species", ".value"),
    names_sep = ":"
  ) %>% 
  filter(!is.na(presence)) %>% 
  mutate(
    date = as_date(analysis_period_start_datetime),
    presence = fct_recode(presence,
      y = "Detected",
      n = "Not Detected",
      m = "Possibly Detected"
    ),
    point = project
  ) %>% 
  select(dataset, species, project, point, date, presence)


# generate points ---------------------------------------------------------

df_points <- df_projects %>%  
  mutate(point = project) %>% 
  select(point, dataset, project, latitude, longitude)

sf_points <- df_points %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

mapview::mapview(sf_points)

# meta summary ------------------------------------------------------------

# unique values
janitor::tabyl(df_projects$platform_type)
janitor::tabyl(df_projects$instrument_type)
janitor::tabyl(df_projects$channel)
janitor::tabyl(df_projects$soundfiles_timezone)
janitor::tabyl(df_projects$duty_cycle_seconds)
janitor::tabyl(df_projects$qc_data)

# timestamps
df_projects %>% 
  select(where(is.Date)) %>%
  table()
df_projects %>% 
  select(where(is.POSIXct)) %>%
  summary()

# numeric values
df_projects %>% 
  select(where(is.numeric)) %>%
  summary()

# detection methods
df_projects_species %>% 
  janitor::tabyl(detection_method, species)

# protocol reference
df_projects_species %>% 
  janitor::tabyl(protocol_reference, detection_method, species)


# detect summary ----------------------------------------------------------

df_detects %>% 
  select(where(is.Date)) %>%
  summary()

df_detects %>% 
  janitor::tabyl(presence, species) %>% 
  janitor::adorn_totals(where = c("row"))

df_detects %>% 
  janitor::tabyl(presence, species) %>% 
  janitor::adorn_percentages("row") %>% 
  janitor::adorn_pct_formatting(digits = 0)

# n_validated_detections only used for (some) NARW detections
# df_detects %>% 
#   janitor::tabyl(n_validated_detections, species)

# df_detects %>% 
#   janitor::tabyl(call_type, species)


# qaqc --------------------------------------------------------------------

stopifnot(exprs = {
  # no duplicated ids
  all(!duplicated(df_projects$project))
  
  # require columns
  all(!is.na(df_projects$project))
  all(!is.na(select(df_projects, starts_with("data_poc"))))
  all(!is.na(df_projects$instrument_type))
  all(!is.na(select(df_projects, starts_with("submitter_"))))
  all(!is.na(df_projects$submission_date))
  all(!is.na(df_projects$latitude))
  all(!is.na(df_projects$longitude))
  
  all(!is.na(df_detects$project))
  all(!is.na(df_detects$point))
  all(!is.na(df_detects$species))
  all(!is.na(df_detects$presence))
  all(!is.na(select(df_detects, starts_with("analysis_period"))))
  all(!is.na(select(df_detects, starts_with("monitoring_"))))
  
  # enumerated values
  all(df_projects$platform_type %in% c("mooring", "buoy"))
  all(unique(df_detects$presence) %in% c("y", "m", "n"))
  # all(df_detects$analysis_period_effort_seconds == 86400)
  # with(df_detects,
  #   all(analysis_period_effort_seconds == as.numeric(difftime(analysis_period_end_datetime, analysis_period_start_datetime, units = "sec")))
  # )
  
  # range of analysis periods is within monitoring period
  # df_detects %>% 
  #   group_by(id) %>% 
  #   summarise(
  #     analysis_start = min(analysis_period_start_datetime),
  #     analysis_end = min(analysis_period_end_datetime),
  #     .groups = "drop"
  #   ) %>% 
  #   left_join(
  #     df_projects %>% 
  #       select(id, monitoring_start = monitoring_start_datetime, monitoring_end = monitoring_end_datetime) %>% 
  #       mutate(
  #         monitoring_start = floor_date(monitoring_start, unit = "day"),
  #         monitoring_end = floor_date(monitoring_end, unit = "day")
  #       ),
  #     by = "id"
  #   ) %>% 
  #   filter(analysis_start < monitoring_start | analysis_end > monitoring_end) %>% 
  #   nrow() == 0
  
  # no duplicate analysis dates
  # all(
  #   df_detects %>% 
  #     mutate(
  #       analysis_date = as_date(analysis_period_start_datetime)
  #     ) %>% 
  #     group_by(id, species, analysis_date) %>% 
  #     count() %>% 
  #     pull(n) == 1
  # )
  
  # monitoring period end is after start
  all(as.numeric(difftime(df_projects$monitoring_end_datetime, df_projects$monitoring_start_datetime, units = "sec")) > 0)
  # latitude between 0 to 90
  all(df_projects$latitude >= 0)
  all(df_projects$latitude <= 90)
  # latitude between -90 and 0 (west of central meridian)
  all(df_projects$longitude >= -90)
  all(df_projects$longitude <= 0)
  
  # meta and detect contain same ids
  identical(sort(unique(df_projects$project)), sort(unique(df_detects$project)))
})


# warnings ----------------------------------------------------------------

df_gaps <- df_detects %>% 
  select(point, date, species, presence) %>% 
  as_tsibble(key = c(point, species), index = date) %>% 
  count_gaps()
if (nrow(df_gaps) > 0) {
  log_warn("detected {nrow(df_gaps)} gaps")
}


# export ------------------------------------------------------------------

list(
  projects = df_projects,
  points = sf_points,
  detects = df_detects
) %>% 
  saveRDS("rds/moored.rds")
