# ORSTD_20240418

source("_targets.R")

external_dir <- "data/external"
db_tables <- read_rds(file.path(external_dir, "db-tables.rds"))

x <- load_external_submission(
  id = "ORSTD_20240418", 
  root_dir = external_dir, 
  db_tables = db_tables
)

x$metadata %>% 
  filter(n_errors > 0)

x$detectiondata %>% 
  filter(n_errors > 0)

x$gpsdata %>% 
  filter(n_errors > 0)

x$detectiondata %>% 
  select(filename, validation_errors) %>% 
  unnest(validation_errors) %>% 
  tabyl(name)
  # filter(name == "MAX_ANALYSIS_FREQUENCY_RANGE_HZ.out_of_range") %>% 
  # left_join(
  #   x$detectiondata %>% 
  #     select(filename, joined) %>%
  #     unnest(joined),
  #   by = c("filename", "row")
  # )

x$detectiondata$parsed[[1]] %>% 
  tabyl(CALL_TYPE_CODE, SPECIES_CODE, ACOUSTIC_PRESENCE)
  
x$detectiondata$parsed[[1]] %>% 
  distinct(SPECIES_CODE, CALL_TYPE_CODE) %>% 
  anti_join(db_tables$call_type, by = c("SPECIES_CODE", "CALL_TYPE_CODE"))

x$detectiondata %>% 
  select(filename, validation_errors) %>% 
  unnest(validation_errors) %>% 
  filter(name == "ANALYSIS_PERIOD_START_DATETIME.outside_monitoring_period") %>% 
  left_join(
    x$detectiondata %>% 
      select(filename, joined) %>%
      unnest(joined),
    by = c("filename", "row")
  ) %>% 
  view()

x$detectiondata %>% 
  select(filename, validation_errors) %>% 
  unnest(validation_errors) %>% 
  filter(name %in% c("ANALYSIS_PERIOD_START_DATETIME.outside_monitoring_period", "ANALYSIS_PERIOD_END_DATETIME.outside_monitoring_period")) %>% 
  distinct(filename, row) %>% 
  mutate(row = row + 1) %>% 
  group_by(filename) %>% 
  summarise(row = str_c(row, collapse = ","))

x$detectiondata %>% 
  select(filename, validation_errors) %>% 
  unnest(validation_errors) %>% 
  filter(name %in% c("MAX_ANALYSIS_FREQUENCY_RANGE_HZ.out_of_range")) %>% 
  left_join(
    x$detectiondata %>% 
      select(filename, joined) %>%
      unnest(joined),
    by = c("filename", "row")
  ) %>% 
  tabyl(METADATA.SAMPLING_RATE_HZ, MAX_ANALYSIS_FREQUENCY_RANGE_HZ)
  # view()

  
x$detectiondata %>% 
  select(filename, joined) %>%
  unnest(joined) %>% 
  filter(DETECTION_SOFTWARE_NAME == "PAMGuard", MAX_ANALYSIS_FREQUENCY_RANGE_HZ == 288000) %>% 
  filter(METADATA.SAMPLING_RATE_HZ < 288000, METADATA.SAMPLING_RATE_HZ == 256000) %>% 
  distinct(UNIQUE_ID) %>% 
  pull(UNIQUE_ID) %>% 
  dput()
  
x$detectiondata %>% 
  select(filename, joined) %>%
  unnest(joined) %>% 
  filter(
    DETECTION_SOFTWARE_NAME == "PAMGuard" &
    MAX_ANALYSIS_FREQUENCY_RANGE_HZ == 288000 &
    UNIQUE_ID %in% c("SWFSC_NEPac-BCN_201810_CCES_017", "SWFSC_NEPac-HUM_201807_CCES_004", 
                     "SWFSC_NEPac-BCN_201608_Pascal_007", "SWFSC_NEPac-CHI_201608_Pascal_008", 
                     "SWFSC_NEPac-COL_201608_Pascal_013", "SWFSC_NEPac-MBY_201609_Pascal_018", 
                     "SWFSC_NEPac-MND_201608_Pascal_010", "SWFSC_NEPac-ORE_201608_Pascal_011", 
                     "SWFSC_NEPac-PTA_201609_Pascal_017")
  ) %>% 
  tabyl(METADATA.SAMPLING_RATE_HZ)
  view()
  