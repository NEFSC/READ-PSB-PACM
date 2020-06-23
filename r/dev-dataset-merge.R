# merge datasets from gen, hansen

library(tidyverse)

df_gen <- read_csv("~/Dropbox/Work/nefsc/transfers/20200420 - multispecies dataset/NOAA_5_Species_Detection_Data_2004-2019_04-20-2020.csv", col_types = cols(
  .default = col_character(),
  PLATFORM_ID = col_character(),
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
  janitor::clean_names() %>% 
  mutate(analysis_date = as.character(as_date(analysis_period_start_date_time))) %>% 
  select(-c("blue_presence", "sei_presence", "humpback_presence", "fin_presence"))

df_hansen <- read_csv(
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
  )
) %>% 
  janitor::clean_names() %>% 
  rename(analysis_period_start_date_time = analysis_period_start_datetime, analysis_period_end_date_time = analysis_period_end_datetime) %>% 
  select(-year, -mday, -monitoring_duration)

setdiff(names(df_gen), names(df_hansen))
setdiff(names(df_hansen), names(df_gen))



setdiff(unique(df_hansen$project), unique(df_gen$project))
setdiff(unique(df_hansen$project), unique(df_gen$project))

df <- bind_rows(
  df_gen %>% mutate(dataset = "gen"),
  df_hansen %>% mutate(dataset = "hansen")
)

df_project <- df %>% 
  group_by(dataset, project, platform_id, site_id, instrument_type, monitoring_start_datetime, monitoring_end_datetime) %>% 
  tally() %>% 
  ungroup() %>% 
  spread(dataset, n)

df_project %>% 
  filter(gen != hansen) %>% 
  print(n = Inf)

# Gen's dataset matches monitoring_start_datetime, monitoring_end_datetime
# otherwise the same
df %>%
  filter(project == "NEFSC_SC_201612_CH6") %>%
  select(dataset, analysis_date, narw_presence) %>%
  spread(dataset, narw_presence) %>%
  print(n = Inf)

# projects missing from Gen's dataset
df_project %>% 
  filter(is.na(gen)) %>% 
  arrange(project) %>% 
  print(n = Inf)

# projects missing from Hansen's dataset
df_project %>% 
  filter(is.na(hansen)) %>% 
  arrange(project) %>% 
  print(n = Inf)

