library(tidyverse)
library(janitor)
library(sf)

dir <- "data-raw/legacy/_rejected/ORSTD_20251110_RevWindConstruction2024"


# thayer mahan -----------------------------------------------------------
# metadata missing UNIQUE_ID, unable to match

raw_metadata_tm <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "METADATA[.]csv", full.names = TRUE, recursive = TRUE),
  id = "$file",
  col_types = cols(.default = col_character())
) |> 
  remove_empty(which = c("rows", "cols"))

raw_detections_tm <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA[.]csv", full.names = TRUE, recursive = TRUE) |> 
  map_dfr(function (x) {
    read_csv(
      x,
      col_types = cols(.default = col_character())
    ) |> 
      remove_empty(which = c("rows", "cols")) |> 
      mutate(
        `$file` = x,
        .before = 1
      )
  })


# orstd -----------------------------------------------------------------

raw_metadata <- list.files(file.path(dir, "raw"), pattern = "METADATA[.]xlsx", full.names = TRUE, recursive = TRUE) |> 
  map_dfr(function (x) {
    readxl::read_excel(x) |> 
      remove_empty(which = c("rows", "cols")) |> 
      mutate(
        `$file` = x,
        .before = 1
      )
  }) |> 
  mutate(
    UNIQUE_ID = str_replace(UNIQUE_ID, " ", ""),
    UNIQUE_ID = str_replace(UNIQUE_ID, "ORST_", "ORSTD_"),
    UNIQUE_ID = toupper(UNIQUE_ID),
    UNIQUE_ID = glue("{UNIQUE_ID}_2024")
  )
raw_detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA[.]xlsx", full.names = TRUE, recursive = TRUE) |> 
  map_dfr(function (x) {
    readxl::read_excel(x) |> 
      remove_empty(which = c("rows", "cols")) |> 
      mutate(
        `$file` = x,
        .before = 1
      )
  }) |> 
  mutate(
    UNIQUE_ID = str_replace(UNIQUE_ID, " ", ""),
    UNIQUE_ID = str_replace(UNIQUE_ID, "ORST_", "ORSTD_"),
    UNIQUE_ID = toupper(UNIQUE_ID),
    UNIQUE_ID = glue("{UNIQUE_ID}_2024")
  )

raw_metadata |> 
  distinct(UNIQUE_ID, LATITUDE, LONGITUDE) |> 
  st_as_sf(coords = c("LONGITUDE", "LATITUDE"), crs = 4326) |>
  mapview::mapview(zcol = "UNIQUE_ID")

metadata_nest <- raw_metadata |> 
  arrange(UNIQUE_ID, MONITORING_START_DATETIME) |>
  mutate(
    STATIONARY_OR_MOBILE = "MOBILE",
    PLATFORM_TYPE = case_when(
      PLATFORM_TYPE == "Surface-buoy" ~ "DRIFTING_BUOY",
      TRUE ~ PLATFORM_TYPE
    ),
    INSTRUMENT_TYPE = case_when(
      INSTRUMENT_TYPE == "RSA-ORCA" ~ "RSA_ORCA",
      TRUE ~ NA_character_
    )
  ) |>
  nest(
    .by = c("UNIQUE_ID", "PROJECT", "STATIONARY_OR_MOBILE", "PLATFORM_TYPE", "CHANNEL", "SOUNDFILES_TIMEZONE", "SAMPLING_RATE_HZ", "SAMPLE_BITS", "RECORDING_INTERVAL_SECONDS")
  )

metadata <- metadata_nest |> 
  mutate(
    PLATFORM_NO = map_chr(data, ~ str_c(unique(na.omit(.$PLATFORM_NO)), collapse = ",")),
    SITE_ID = NA_character_,
    INSTRUMENT_TYPE = map_chr(data, ~ str_c(unique(na.omit(.$INSTRUMENT_TYPE)), collapse = ",")),
    INSTRUMENT_ID = map_chr(data, ~ str_c(unique(na.omit(.$INSTRUMENT_ID)), collapse = ",")),
    MONITORING_START_DATETIME = map_chr(data, ~ first(format_ISO8601(.$MONITORING_START_DATETIME))),
    MONITORING_END_DATETIME = map_chr(data, ~ last(format_ISO8601(.$MONITORING_END_DATETIME))),
    # LATITUDE = map_dbl(data, ~ mean(.$LATITUDE, na.rm = TRUE)),
    # LONGITUDE = map_dbl(data, ~ mean(.$LONGITUDE, na.rm = TRUE)),
    LATITUDE = NA_real_,
    LONGITUDE = NA_real_,
    WATER_DEPTH_METERS = map_dbl(data, ~ mean(.$WATER_DEPTH_METERS, na.rm = TRUE)),
    RECORDER_DEPTH_METERS = map_dbl(data, ~ mean(.$RECORDER_DEPTH_METERS, na.rm = TRUE)),
    RECORDING_DURATION_SECONDS = map_dbl(data, ~ sum(.$RECORDING_DURATION_SECONDS)),
  ) |> 
  select(-data)
tabyl(metadata, UNIQUE_ID)
tabyl(metadata, PLATFORM_TYPE, INSTRUMENT_TYPE)
stopifnot(!anyDuplicated(metadata$UNIQUE_ID))

gpsdata <- raw_metadata |> 
  select(UNIQUE_ID, DATETIME = MONITORING_START_DATETIME, LATITUDE, LONGITUDE) |> 
  arrange(UNIQUE_ID, DATETIME) |> 
  filter(LATITUDE > 1)

gpsdata |> 
  st_as_sf(coords = c("LONGITUDE", "LATITUDE"), crs = 4326) |>
  group_by(UNIQUE_ID) |> 
  summarise(
    do_union = FALSE
  ) |> 
  st_cast("LINESTRING") |> 
  ungroup() |> 
  mapview::mapview(zcol = "UNIQUE_ID")

# gps interpolators
gps_interp <- gpsdata |> 
  slice_head(n = 1, by = c(UNIQUE_ID, DATETIME)) |> 
  nest(data = -UNIQUE_ID) |> 
  mutate(
    interp_latitude = map(data, ~ approxfun(x = as.numeric(.$DATETIME), y = .$LATITUDE, rule = 2)),
    interp_longitude = map(data, ~ approxfun(x = as.numeric(.$DATETIME), y = .$LONGITUDE, rule = 2)),
    interp = map2(interp_latitude, interp_longitude, ~ list(
      lat = .x,
      lon = .y
    ))
  ) |> 
  select(UNIQUE_ID, interp) |> 
  deframe()

analyses <- raw_detections |> 
  filter(!is.na(UNIQUE_ID)) |> 
  mutate(
    DETECTION_SOFTWARE_VERSION = "2.02",
    N_VALIDATED_DETECTIONS = as.numeric(na_if(N_VALIDATED_DETECTIONS, "NA")),
    DETECTION_LATITUDE = map2_dbl(UNIQUE_ID, ANALYSIS_PERIOD_START_DATETIME, function (x, y) {
      gps_interp[[x]]$lat(as.numeric(y))
    }),
    DETECTION_LONGITUDE = map2_dbl(UNIQUE_ID, ANALYSIS_PERIOD_START_DATETIME, function (x, y) {
      gps_interp[[x]]$lon(as.numeric(y))
    })
  ) |> 
  filter(SPECIES_CODE != "D; D") |> 
  select(-`$file`) |> 
  nest(detections = -c(
    UNIQUE_ID, ANALYSIS_TIME_ZONE, SPECIES_CODE, DETECTION_METHOD, PROTOCOL_REFERENCE,
    DETECTION_SOFTWARE_NAME, ANALYSIS_SAMPLING_RATE_HZ, QC_PROCESSING,
    MIN_ANALYSIS_FREQUENCY_RANGE_HZ, MAX_ANALYSIS_FREQUENCY_RANGE_HZ
  ))
tabyl(analyses, UNIQUE_ID, SPECIES_CODE)
tabyl(analyses, MIN_ANALYSIS_FREQUENCY_RANGE_HZ, MAX_ANALYSIS_FREQUENCY_RANGE_HZ)

analyses |> 
  add_count(UNIQUE_ID, SPECIES_CODE) |>
  filter(n > 1)

raw_detections |> 
  tabyl(CALL_TYPE_CODE)

stopifnot(
  analyses |> 
    count(UNIQUE_ID, SPECIES_CODE) |>
    filter(n > 1) |> 
    nrow() == 0,
  all(analyses$UNIQUE_ID %in% metadata$UNIQUE_ID)
)

detections_daily <- analyses |> 
  mutate(
    detections = map(detections, function (x) {
      x |> 
        mutate(
          DATE = as_date(ANALYSIS_PERIOD_START_DATETIME)
        ) |>
        group_by(DATE) |> 
        summarise(
          ANALYSIS_PERIOD_START_DATETIME = min(ANALYSIS_PERIOD_START_DATETIME),
          ANALYSIS_PERIOD_END_DATETIME = max(ANALYSIS_PERIOD_END_DATETIME),
          ANALYSIS_PERIOD_EFFORT_SECONDS = sum(ANALYSIS_PERIOD_EFFORT_SECONDS),
          ACOUSTIC_PRESENCE = case_when(
            any(ACOUSTIC_PRESENCE == "D") ~ "D",
            any(ACOUSTIC_PRESENCE == "N") ~ "N",
            TRUE ~ NA_character_
          ),
          N_VALIDATED_DETECTIONS = sum(N_VALIDATED_DETECTIONS),
          CALL_TYPE_CODE = paste(unique(na.omit(CALL_TYPE_CODE)), collapse = ","),
          .groups = "drop"
        )
    })
  ) |> 
  unnest(detections) |> 
  select(-DATE)

detections <- bind_rows(
  detections_daily |> 
    filter(ACOUSTIC_PRESENCE == "N"),
  analyses |> 
    unnest(detections) |>
    filter(ACOUSTIC_PRESENCE == "D")
) |> 
  mutate(
    DETECTION_SOFTWARE_VERSION = NA_character_,
    CALL_TYPE_CODE = map_chr(CALL_TYPE_CODE, ~ str_c(unique(str_trim(str_split_1(.x, ";|,"))), collapse = ","))
  )

tabyl(detections, SPECIES_CODE, ACOUSTIC_PRESENCE)
tabyl(detections, CALL_TYPE_CODE)
tabyl(detections, DETECTION_SOFTWARE_VERSION)

stopifnot(
  all(detections$UNIQUE_ID %in% metadata$UNIQUE_ID),
  all(gpsdata$UNIQUE_ID %in% metadata$UNIQUE_ID)
)
setdiff(unique(gpsdata$UNIQUE_ID), metadata$UNIQUE_ID)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
write_csv(gpsdata, file.path(dir, "clean/gpsdata.csv"), na = "")
