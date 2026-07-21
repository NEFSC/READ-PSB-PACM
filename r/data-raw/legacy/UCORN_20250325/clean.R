library(tidyverse)
library(janitor)

dir <- "data-raw/legacy/UCORN_20250325"

raw_metadata <- read_csv(
  file.path(dir, "raw", "CORNELL_TSS_metadat.csv"),
  col_types = cols(.default = col_character())
)
raw_detections_2019 <- read_csv(
  file.path(dir, "raw", "CORNELL_TSS_DETECTION_DATA.csv"),
  col_types = cols(.default = col_character())
)

metadata <- raw_metadata |> 
  mutate(
    UNIQUE_ID = PROJECT,
    PLATFORM_TYPE = case_when(
      PLATFORM_TYPE == "surface buoy" ~ "MOORED_SURFACE_BUOY",
      TRUE ~ PLATFORM_TYPE
    ),
    INSTRUMENT_TYPE = toupper(INSTRUMENT_TYPE),
    RECORDING_DURATION_SECONDS = 60,
    RECORDING_INTERVAL_SECONDS = 60,
    SAMPLE_BITS = NA_character_,
    STATIONARY_OR_MOBILE = "STATIONARY",
    across(
      c(MONITORING_START_DATETIME, MONITORING_END_DATETIME),
      ~ format_ISO8601(lubridate::mdy_hm(.x, tz = "UTC"))
    ),
    QC_DATA = "REAL_TIME"
  ) |> 
  rename(QC_PROCESSING = QC_DATA) |> 
  mutate(
    MONITORING_END_DATETIME = "2025-02-28T23:59:00Z"
  )
tabyl(metadata, UNIQUE_ID)
tabyl(metadata, PLATFORM_TYPE, INSTRUMENT_TYPE)
tabyl(metadata, QC_PROCESSING)
stopifnot(!anyDuplicated(metadata$UNIQUE_ID))

detections_2019 <- raw_detections_2019 |> 
  rename(CALL_TYPE_CODE = CALL_TYPE) |> 
  mutate(
    UNIQUE_ID = str_remove(UNIQUE_ID, "_\\d+$"),
    QC_PROCESSING = NA_character_,
    ACOUSTIC_PRESENCE = case_when(
      NARW_PRESENCE == "undetected" ~ "n",
      NARW_PRESENCE == "detected" ~ "y",
      TRUE ~ NARW_PRESENCE
    ),
    SPECIES_CODE = "RIWH",
    CALL_TYPE_CODE = case_when(
      CALL_TYPE_CODE == "Upcall" ~ "RW_UPCALL",
      TRUE ~ CALL_TYPE_CODE
    ),
    DETECTION_METHOD = case_when(
      DETECTION_METHOD == "Gillespie edge detector" ~ "GILLESPIE_EDGE",
      TRUE ~ DETECTION_METHOD
    )
  ) |> 
  select(-NARW_PRESENCE)

raw_detections_2023 <- read_csv(
  file.path(dir, "raw", "YangCenter_AutoBuoy_Data_2019-2023.csv"),
  col_types = cols(.default = col_character())
) |> 
  mutate(DATE = lubridate::dmy(DATE)) |> 
  filter(year(DATE) < 2023)
raw_detections_2025 <- readxl::read_excel(
  file.path(dir, "raw", "YangCenter_AutoBuoy_January_2023_to_February_2025.xls"),
  col_types = "text"
) |> 
  rename(DATE = Date) |> 
  mutate(DATE = janitor::excel_numeric_to_date(as.numeric(DATE), date_system = "modern"))

detections_2023_2025 <- bind_rows(
  raw_detections_2023,
  raw_detections_2025
) |> 
  pivot_longer(-DATE, names_to = "UNIQUE_ID", values_to = "N_DETECTIONS") |>
  mutate(N_DETECTIONS = as.integer(N_DETECTIONS)) |> 
  transmute(
    UNIQUE_ID = paste0("CORNELL_TSS_AUTOBUOYS_", as.integer(str_replace(UNIQUE_ID, "AB", ""))),
    ANALYSIS_PERIOD_START_DATETIME = paste0(DATE, "T00:00:00"),
    ANALYSIS_PERIOD_END_DATETIME = paste0(DATE + days(1), "T00:00:00"),
    ACOUSTIC_PRESENCE = case_when(
      N_DETECTIONS == 0 ~ "n",
      N_DETECTIONS > 0 ~ "y",
      TRUE ~ NA_character_
    )
  ) |> 
  bind_cols(
    detections_2019 |> 
      distinct(ANALYSIS_PERIOD_EFFORT_SECONDS, DETECTION_METHOD, PROTOCOL_REFERENCE, SPECIES_CODE, CALL_TYPE_CODE, QC_PROCESSING)
  )

detections <- bind_rows(
  detections_2019,
  detections_2023_2025
)

tabyl(detections, UNIQUE_ID, DETECTION_METHOD)
tabyl(detections, SPECIES_CODE, CALL_TYPE_CODE)
tabyl(detections, DETECTION_METHOD, PROTOCOL_REFERENCE)

stopifnot(
  all(detections$UNIQUE_ID %in% metadata$UNIQUE_ID),
  count(detections, UNIQUE_ID, ANALYSIS_PERIOD_START_DATETIME) |> 
    filter(n > 1) |>
    nrow() == 0
)
skimr::skim(detections)

detections |> 
  ggplot(aes(as_date(ymd_hms(ANALYSIS_PERIOD_START_DATETIME)), ACOUSTIC_PRESENCE)) +
  geom_point() +
  facet_wrap(~UNIQUE_ID)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
