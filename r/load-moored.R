# load buoy/mooring dataset

library(tidyverse)
library(lubridate)
library(tsibble)
library(logger)

log_threshold(DEBUG)

FILE_META <- "~/Dropbox/Work/nefsc/transfers/20200804 - mooring and glider data/Moored_metadata_2020-08-04.csv"
FILE_DETECT <- "~/Dropbox/Work/nefsc/transfers/20200804 - mooring and glider data/Moored_detection_data_2020-08-04.csv"

# load metadata -----------------------------------------------------------

df_meta_csv <- read_csv(
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

df_meta_all <- df_meta_csv %>%
  mutate(
    submission_date = ymd(submission_date),
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime)
  ) %>% 
  select(unique_id, everything()) # bring unique_id to first column


# load detect data --------------------------------------------------------

df_detect_csv <- read_csv(
  FILE_DETECT,
  col_types = cols(
    .default = col_character(),
    ANALYSIS_PERIOD_EFFORT_SECONDS = col_double(),
    NARW_N_VALIDATED_DETECTIONS = col_integer()
  )
) %>% 
  janitor::clean_names()

df_detect_all <- df_detect_csv %>% 
  mutate(
    analysis_period_start_datetime = ymd_hms(analysis_period_start_datetime),
    analysis_period_end_datetime = ymd_hms(analysis_period_end_datetime)
  )


# screen projects ---------------------------------------------------------

# only projects with detection data
projects_no_detections <- setdiff(unique(df_meta_all$unique_id), unique(df_detect_all$unique_id))
log_info("excluding projects with no detection data (n = {length(projects_no_detections)})")

# only projects with valid lat/lon
projects_invalid_latlon <- df_meta_all %>% 
  filter(is.na(latitude) | is.na(longitude)) %>% 
  pull(unique_id)
log_info("excluding projects with invalid lat/lon (n = {length(projects_invalid_latlon)})")

df_meta <- df_meta_all %>% 
  filter(!unique_id %in% c(projects_no_detections, projects_invalid_latlon)) %>%
  rename_with(
    ~ str_replace(., "_", ":"),
    starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
  ) %>% 
  pivot_longer(
    starts_with(c("narw", "humpback", "sei", "fin", "blue")),
    names_to = c("species", ".value"),
    names_sep = ":",
    values_drop_na = TRUE
  )

df_detect <- df_detect_all %>% 
  filter(unique_id %in% df_meta$unique_id) %>% 
  rename_with(
    ~ str_replace(., "_", ":"),
    starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
  ) %>% 
  pivot_longer(
    starts_with(c("narw", "humpback", "sei", "fin", "blue")),
    names_to = c("species", ".value"),
    names_sep = ":"
  ) %>% 
  filter(!is.na(presence))


# meta summary ------------------------------------------------------------

# unique values
janitor::tabyl(df_meta$platform_type)
janitor::tabyl(df_meta$instrument_type)
janitor::tabyl(df_meta$channel)
janitor::tabyl(df_meta$soundfiles_timezone)
janitor::tabyl(df_meta$duty_cycle_seconds)
janitor::tabyl(df_meta$qc_data)

# timestamps
df_meta %>% 
  select(where(is.Date)) %>%
  table()
df_meta %>% 
  select(where(is.POSIXct)) %>%
  summary()

# numeric values
df_meta %>% 
  select(where(is.numeric)) %>%
  summary()

# detection methods
df_meta %>% 
  janitor::tabyl(detection_method, species)

# protocol reference
df_meta %>% 
  janitor::tabyl(protocol_reference, detection_method, species)


# detect summary ----------------------------------------------------------

df_detect %>% 
  select(where(is.POSIXct)) %>%
  summary()

df_detect %>% 
  janitor::tabyl(presence, species) %>% 
  janitor::adorn_totals(where = c("row"))

df_detect %>% 
  janitor::tabyl(presence, species) %>% 
  janitor::adorn_percentages("row") %>% 
  janitor::adorn_pct_formatting(digits = 0)

# n_validated_detections only used for (some) NARW detections
df_detect%>% 
  janitor::tabyl(n_validated_detections, species)

df_detect %>% 
  janitor::tabyl(call_type, species)


# qaqc --------------------------------------------------------------------

stopifnot(exprs = {
  # no duplicated ids
  all(!duplicated(str_c(df_meta$unique_id, df_meta$species)))
  
  # require columns
  all(!is.na(df_meta$project))
  all(!is.na(select(df_meta, starts_with("data_poc"))))
  all(!is.na(df_meta$instrument_type))
  all(!is.na(select(df_meta, starts_with("submitter_"))))
  all(!is.na(df_meta$submission_date))
  all(!is.na(df_meta$latitude))
  all(!is.na(df_meta$longitude))
  all(!is.na(df_detect$unique_id))
  all(!is.na(df_detect$species))
  all(!is.na(df_detect$presence))
  all(!is.na(select(df_detect, starts_with("analysis_period"))))
  all(!is.na(select(df_detect, starts_with("monitoring_"))))
  
  # enumerated values
  all(df_meta$platform_type %in% c("Mooring", "surface buoy"))
  all(unique(df_detect$presence) %in% c("Detected", "Possibly Detected", "Not Detected"))
  all(df_detect$analysis_period_effort_seconds == 86400)
  with(df_detect,
    all(analysis_period_effort_seconds == as.numeric(difftime(analysis_period_end_datetime, analysis_period_start_datetime, units = "sec")))
  )
  
  # range of analysis periods is within monitoring period
  df_detect %>% 
    group_by(unique_id) %>% 
    summarise(
      analysis_start = min(analysis_period_start_datetime),
      analysis_end = min(analysis_period_end_datetime),
      .groups = "drop"
    ) %>% 
    left_join(
      df_meta %>% 
        select(unique_id, monitoring_start = monitoring_start_datetime, monitoring_end = monitoring_end_datetime) %>% 
        mutate(
          monitoring_start = floor_date(monitoring_start, unit = "day"),
          monitoring_end = floor_date(monitoring_end, unit = "day")
        ),
      by = "unique_id"
    ) %>% 
    filter(analysis_start < monitoring_start | analysis_end > monitoring_end) %>% 
    nrow() == 0
  
  # no duplicate analysis dates
  all(
    df_detect %>% 
      mutate(
        analysis_date = as_date(analysis_period_start_datetime)
      ) %>% 
      group_by(unique_id, species, analysis_date) %>% 
      count() %>% 
      pull(n) == 1
  )
  
  # monitoring period end is after start
  all(as.numeric(difftime(df_meta$monitoring_end_datetime, df_meta$monitoring_start_datetime, units = "sec")) > 0)
  # latitude between 0 to 90
  all(df_meta$latitude >= 0)
  all(df_meta$latitude <= 90)
  # latitude between -90 and 0 (west of central meridian)
  all(df_meta$longitude >= -90)
  all(df_meta$longitude <= 0)
  
  # meta and detect contain same ids
  identical(sort(unique(df_meta$unique_id)), sort(unique(df_detect$unique_id)))
})

# warnings ----------------------------------------------------------------

df_gaps <- df_detect %>% 
  mutate(
    analysis_date = as_date(analysis_period_start_datetime)
  ) %>% 
  select(unique_id, analysis_date, species, presence) %>% 
  as_tsibble(key = c(unique_id, species), index = analysis_date) %>% 
  count_gaps()
if (nrow(df_gaps) > 0) {
  log_warn("detected {nrow(df_gaps)} gaps")
}

# export ------------------------------------------------------------------

list(
  meta = df_meta,
  detect = df_detect
) %>% 
  saveRDS("rds/moored.rds")
