# process dataset file

library(tidyverse)
library(lubridate)


# load csv ----------------------------------------------------------------

# df_csv <- read_csv("~/Dropbox/Work/nefsc/transfers/20191011 - data files/NEFSC_NARW_presence_all_2018-10-30.csv", col_types = cols(
df_csv <- read_csv("~/Dropbox/Work/nefsc/transfers/20200115 - multispecies dataset/NOAA_5_Species_Detection_Data_2004-2019_01-15-2020.csv", col_types = cols(
  .default = col_character(),
  PLATFORM_ID = col_logical(),
  SITE_ID = col_character(),
  INSTRUMENT_ID = col_character(),
  CHANNEL = col_double(),
  LATITUDE = col_double(),
  LONGITUDE = col_double(),
  WATER_DEPTH_METERS = col_double(),
  RECORDER_DEPTH_METERS = col_double(),
  SAMPLING_RATE_HZ = col_double(),
  ANALYSIS_PERIOD_EFFORT_SECONDS = col_double(),
  N_VALIDATED_DETECTIONS = col_double()
)) %>% 
  janitor::clean_names()

glimpse(df_csv)


# qaqc --------------------------------------------------------------------

# failed to parse
df_csv %>% 
  filter(is.na(ymd_hms(monitoring_end_datetime)))
df_csv %>% 
  filter(is.na(ymd_hms(analysis_period_start_date_time)))
df_csv %>% 
  filter(is.na(ymd_hms(analysis_period_end_date_time)))
df_csv %>% 
  filter(is.na(latitude))
df_csv %>% 
  filter(is.na(longitude))
df_csv %>% 
  filter(is.na(site_id))

# invalid longitude
df_csv %>% 
  filter(longitude > 0) %>% 
  select(project, site_id, latitude, longitude) %>% 
  distinct()

# sites with differing lat/lon
df_csv %>% 
  mutate(monitoring_start = format(ymd_hms(monitoring_start_datetime), "%Y%m%d")) %>% 
  select(project, site_id, latitude, longitude, monitoring_start) %>% 
  distinct() %>% 
  group_by(project, site_id) %>% 
  mutate(n = n()) %>% 
  ungroup() %>% 
  filter(n > 1)

# multiple identical rows with varying fin_presence
df_csv %>% 
  group_by(project, site_id, analysis_period_start_date_time) %>% 
  add_tally() %>% 
  filter(n > 1) %>% 
  select(project, site_id, ends_with("presence"), n)

# project: NEFSC_SBNMS_200601
# site: 6
# rename to 6A and 6B
# df_csv <- df_csv %>% 
#   mutate(
#     site_id = case_when(
#       project == "NEFSC_SBNMS_200601" & site_id == "6" & instrument_id == "96" ~ "6A",
#       project == "NEFSC_SBNMS_200601" & site_id == "6" & instrument_id == "96 (re-deploy)" ~ "6B",
#       TRUE ~ site_id
#     )
#   )

# df_csv %>% 
#   filter(project == "NEFSC_SBNMS_200601") %>% 
#   select(site_id, latitude, longitude) %>% 
#   distinct()


# clean -------------------------------------------------------------------

df <- df_csv %>% 
  mutate(
    site_id = coalesce(site_id, "N/A"),
    longitude = if_else(longitude > 0, -1 * longitude, longitude),
    submission_date = ymd(submission_date),
    monitoring_start_datetime = ymd_hms(monitoring_start_datetime),
    monitoring_end_datetime = ymd_hms(monitoring_end_datetime),
    analysis_period_start_date_time = ymd_hms(analysis_period_start_date_time),
    analysis_period_end_date_time = ymd_hms(analysis_period_end_date_time)
  ) %>% 
  filter(
    !is.na(latitude),
    !is.na(longitude),
    !is.na(analysis_period_start_date_time),
    !is.na(analysis_period_end_date_time)
  ) %>% 
  select(-fin_presence) %>% 
  distinct()

table(df$detection_method)
table(df$platform_type)
table(df$instrument_type)

deployment_variables <- names(df)[1:26]
detection_variables <- c("project", "site_id", names(df)[27:length(names(df))])

df_deployments <- df %>% 
  select(deployment_variables) %>% 
  distinct()

stopifnot(
  df_deployments %>% 
    select(project, site_id, latitude, longitude) %>% 
    distinct() %>% 
    group_by(project, site_id) %>% 
    count() %>% 
    filter(n > 1) %>% 
    nrow() == 0
)

df_detections <- df %>% 
  select(detection_variables) %>% 
  transmute(
    project = project,
    site_id = site_id,
    date = as_date(analysis_period_start_date_time),
    narw_presence = narw_presence,
    blue_presence = blue_presence,
    sei_presence = sei_presence,
    humpback_presence = humpback_presence
    # fin_presence = fin_presence
  ) %>% 
  distinct() %>% 
  pivot_longer(ends_with("_presence"), names_to = "species", values_to = "presence") %>% 
  mutate(
    species = str_replace(species, "_presence", ""),
    presence = case_when(
      presence == "Detected" ~ "yes",
      presence == "Not Detected" ~ "no",
      presence == "Possibly Detected" ~ "maybe",
      TRUE ~ NA_character_
    )
  ) %>%
  pivot_wider(names_from = species, values_from = presence) %>% 
  arrange(project, site_id, date)

stopifnot(
  df_detections %>% 
    group_by(project, site_id, date) %>% 
    count() %>% 
    filter(n > 1) %>% 
    nrow() == 0
)

# stopifnot(all(!is.na(df_detections)))

glimpse(df_deployments)
glimpse(df_detections)

df_detections %>% 
  select(-project, -site_id, -date) %>% 
  pivot_longer(cols = everything(), names_to = "species", values_to = "value") %>% 
  janitor::tabyl(value, species) %>% 
  janitor::adorn_percentages("row") %>% 
  janitor::adorn_pct_formatting(digits = 0)

# export ------------------------------------------------------------------

df_deployments %>% 
  write_csv("../public/data/deployments.csv", na = "")
df_detections %>% 
  pivot_longer(-c(project, site_id, date), names_to = "species", values_to = "detection", values_drop_na = TRUE) %>%
  write_csv("../public/data/detections.csv", na = "")

list(
  deployments = df_deployments,
  detections = df_detections
) %>% 
  saveRDS("rds/dataset.rds")
