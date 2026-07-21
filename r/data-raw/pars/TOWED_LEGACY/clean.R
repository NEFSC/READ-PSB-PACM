# TOWED_LEGACY - NEFSC/SEFSC towed array surveys, 2011-2019
#
# Converts the survey's original workbooks in raw/ into PARS-format files in
# clean/. This replaces R/towed/, where the same conversion was spread across
# ~60 targets, one per source file (AD-11).
#
# raw/ is immutable submitted data and is never written to.
#
# This file produces metadata.csv and gpsdata.csv (T2.2). detectiondata.csv is
# added in T2.3, and only then can the submission be un-skipped in
# data-raw/pars/submissions.csv.

library(tidyverse)
library(readxl)
library(janitor)

dir <- "data-raw/pars/TOWED_LEGACY"
raw_dir <- file.path(dir, "raw")
tracks_dir <- file.path(raw_dir, "tracks")

metadata_file <- file.path(
  raw_dir, "Towed_Array_effort_Walker_Website_Daily_Resolution.xlsx"
)

# PARS requires timezone-aware timestamps. every datetime in this submission is
# naive in the source workbooks and UTC by convention; `stamp_utc` makes that
# conversion explicit and `recording_timezone` is asserted below rather than
# assumed, so a future non-UTC source fails loudly instead of shifting silently
stamp_utc <- function (x) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%S+0000")
}

# cruise dates -------------------------------------------------------------
#
# the effort record: which days of each cruise were on-effort, by leg. used
# here to keep off-effort positions (transits, port calls) out of gpsdata,
# since PARS gpsdata has no effort flag and any position written to it becomes
# track geometry

cruise_dates <- read_excel(metadata_file, sheet = "Cruise_dates") |>
  clean_names() |>
  mutate(across(c(start, end), as_date)) |>
  transmute(
    deployment_code = if_else(
      cruise %in% c("GU1303", "GU1605"),
      str_c("SEFSC_", cruise),
      str_c("NEFSC_", cruise)
    ),
    start,
    end
  ) |>
  arrange(deployment_code, start) |>
  group_by(deployment_code) |>
  mutate(leg = row_number()) |>
  ungroup() |>
  rowwise() |>
  mutate(date = list(seq.Date(start, end, by = "day"))) |>
  unnest(date) |>
  select(-start, -end)

# gps tracks ---------------------------------------------------------------
#
# one reader per cruise, ported from R/towed/towed-tracks.R. the per-file
# quirks (sheet ranges, column spellings, date formats, coordinate filters) are
# properties of the submitted files, so they stay here rather than being
# normalised away

read_track <- function (path, code, datetime_column, ...) {
  read_excel(path, ...) |>
    clean_names() |>
    transmute(
      deployment_code = code,
      datetime = .data[[datetime_column]],
      latitude,
      longitude
    )
}

tracks_gu1303 <- read_track(
  file.path(tracks_dir, "GU1303_gpsData.xlsx"), "SEFSC_GU1303", "utc"
)
tracks_gu1402 <- read_track(
  file.path(tracks_dir, "GU1402_GPS_data.xlsx"), "NEFSC_GU1402", "utc"
)
tracks_gu1605 <- read_track(
  file.path(tracks_dir, "GU1605_allGPS_Corrected.xlsx"), "SEFSC_GU1605", "utc"
)

# one file per day, with an effort flag and some out-of-region bad fixes
tracks_gu1803 <- list.files(
  file.path(tracks_dir, "GU1803_ShipGPS_EffortAppended_FIXED"),
  full.names = TRUE
) |>
  map_df(~ clean_names(read_excel(.x))) |>
  filter(user_field >= 0, longitude > -90, longitude < -30, latitude < 90) |>
  transmute(
    deployment_code = "NEFSC_GU1803",
    datetime = date_time_utc,
    latitude,
    longitude
  )

tracks_hb1103 <- bind_rows(
  read_track(
    file.path(tracks_dir, "HB1103_gpsData.xlsx"), "NEFSC_HB1103", "utc"
  ),
  read_track(
    file.path(tracks_dir, "HB1103_GPS_data_0729-0730.xlsx"),
    "NEFSC_HB1103", "utc"
  )
)

tracks_hb1303 <- read_track(
  file.path(tracks_dir, "HB1303_PG_GPS_ALL_AIedits.xlsx"),
  "NEFSC_HB1303", "utc"
)

# five sheets, each with an explicit range because trailing rows are junk
hb1403_file <- file.path(tracks_dir, "HB1403_Completed_GpsData_AIedits.xlsx")
hb1403_ranges <- c(
  "A1:Q28830", "A1:T86072", "A1:T59256", "A1:T30509", "A1:T14141"
)
tracks_hb1403 <- imap(hb1403_ranges, function (range, sheet) {
  read_track(
    hb1403_file, "NEFSC_HB1403", "gps_date", sheet = sheet, range = range
  )
}) |>
  bind_rows()

tracks_hb1503 <- bind_rows(
  read_track(
    file.path(tracks_dir, "HB1503_20150615_gpsData.xlsx"),
    "NEFSC_HB1503", "utc"
  ) |>
    # this one file records UTC as an m/d/y string rather than a datetime
    mutate(datetime = mdy_hms(datetime)),
  read_track(
    file.path(tracks_dir, "HB1503_Copy of Leg1_gps_June16-18.xlsx"),
    "NEFSC_HB1503", "utc"
  ),
  read_track(
    file.path(tracks_dir, "HB1503_Leg2_ShipGPS.xlsx"), "NEFSC_HB1503", "utc"
  )
)

# 22 columns; the last must be read as text or readxl guesses wrong
tracks_hb1603 <- read_track(
  file.path(tracks_dir, "HB1603_ship_GPS_EchoAdd_All_legs_combined.xlsx"),
  "NEFSC_HB1603", "utc",
  col_types = c(rep("guess", times = 21), "text")
)

tracks_hrs1701 <- read_csv(
  file.path(tracks_dir, "HRS1701_Skala_gpsData.csv"),
  col_types = cols(
    .default = col_double(),
    Date_UTC = col_character(),
    UTC = col_character(),
    PCLocalTime = col_character(),
    PCTime = col_character(),
    GpsDate = col_character(),
    SpeedType = col_character(),
    HeadingType = col_logical(),
    TrueHeading = col_logical(),
    MagneticHeading = col_logical(),
    DataStatus = col_character()
  )
) |>
  clean_names() |>
  transmute(
    deployment_code = "NEFSC_HRS1701",
    datetime = mdy_hms(utc),
    latitude,
    longitude
  )

tracks_hrs1910 <- read_csv(
  file.path(tracks_dir, "HRS1910_ship_GPS.csv"),
  col_types = cols(
    .default = col_double(),
    UTC = col_datetime(format = ""),
    PCLocalTime = col_datetime(format = ""),
    PCTime = col_datetime(format = ""),
    SequenceBitmap = col_logical(),
    GpsDate = col_datetime(format = ""),
    SpeedType = col_character(),
    HeadingType = col_logical(),
    TrueHeading = col_logical(),
    MagneticHeading = col_logical(),
    DataStatus = col_character(),
    FixType = col_character()
  )
) |>
  clean_names() |>
  transmute(
    deployment_code = "NEFSC_HRS1910",
    datetime = utc,
    latitude,
    longitude
  )

track_positions <- bind_rows(
  tracks_gu1303, tracks_gu1402, tracks_gu1605, tracks_gu1803,
  tracks_hb1103, tracks_hb1303, tracks_hb1403, tracks_hb1503,
  tracks_hb1603, tracks_hrs1701, tracks_hrs1910
) |>
  arrange(deployment_code, datetime)

# thin to one position per hour, then drop off-effort days.
#
# thinning here rather than shipping ~2.3 M raw fixes keeps the submission a
# reasonable size and changes nothing downstream: derive_tracks() thins to the
# first position in each hour anyway, so re-thinning already-hourly data is a
# no-op. full resolution remains in raw/
gpsdata <- track_positions |>
  mutate(datetime_hour = floor_date(datetime, unit = "hour")) |>
  group_by(deployment_code, datetime_hour) |>
  slice_min(order_by = datetime, n = 1) |>
  ungroup() |>
  select(-datetime_hour) |>
  mutate(date = as_date(datetime)) |>
  semi_join(cruise_dates, by = c("deployment_code", "date")) |>
  select(-date) |>
  arrange(deployment_code, datetime)

# every cruise-day of effort must have track coverage, or the leg it belongs to
# would silently lose geometry
stopifnot(
  nrow(anti_join(
    cruise_dates,
    mutate(gpsdata, date = as_date(datetime)),
    by = c("deployment_code", "date")
  )) == 0
)

# metadata -----------------------------------------------------------------

metadata_raw <- read_excel(metadata_file, sheet = "Towed_array_metadata") |>
  clean_names()

# the sheet has one row per deployment x species; deployment attributes repeat
stopifnot(
  nrow(metadata_raw) == 31,
  all(metadata_raw$platform_type == "Towed Array, linear"),
  # every datetime in this submission is stamped UTC on that basis
  all(metadata_raw$soundfiles_timezone == "UTC"),
  # "continuous" rather than a number, so the PARS duty-cycle fields stay blank
  all(metadata_raw$duty_cycle_seconds == "continuous")
)

# the recording configuration comes only from rows that were actually analysed,
# matching towed_recordings.
#
# a deployment can have several analysed rows naming different hydrophones -
# HB1603 records "HTI-96-min" for beaked and "HTI-96-min & Reson" for kogia -
# and the published instrument_type is their sorted union. reproduced here so
# the device type is unchanged by the conversion
recordings <- metadata_raw |>
  filter(as.logical(analyzed)) |>
  transmute(
    deployment_code = project,
    sampling_rate_hz,
    device_type_code = case_when(
      instrument_type == "HTI-96-min & Reson" ~ "HTI-96-MIN,RESON",
      TRUE ~ toupper(instrument_type)
    )
  ) |>
  group_by(deployment_code) |>
  summarise(
    n_sample_rates = n_distinct(sampling_rate_hz),
    sampling_rate_hz = first(sampling_rate_hz),
    device_type_code = str_c(
      sort(unique(unlist(str_split(device_type_code, ",")))),
      collapse = ","
    ),
    .groups = "drop"
  )

# PARS carries one recording configuration per deployment, so a deployment with
# two analysed sample rates could not be represented without losing one
stopifnot(all(recordings$n_sample_rates == 1))

# PARS takes a mobile deployment's position to be the start of its track.
#
# some timestamps carry more than one position - HB1503's three source files
# overlap in time, and several cruises repeat a fix - so the earliest datetime
# can match several rows. those duplicates are preserved in gpsdata because the
# current pipeline preserves them, but the deployment position must resolve to
# one row, and it is only well defined if the tied rows agree
deployment_first <- gpsdata |>
  group_by(deployment_code) |>
  filter(datetime == min(datetime)) |>
  ungroup()

stopifnot(
  nrow(distinct(deployment_first, deployment_code, latitude, longitude)) ==
    n_distinct(gpsdata$deployment_code)
)

deployment_positions <- deployment_first |>
  distinct(deployment_code, latitude, longitude)

metadata <- metadata_raw |>
  distinct(
    project, data_poc_name, monitoring_start_datetime, monitoring_end_datetime
  ) |>
  transmute(
    deployment_organization_code = str_sub(project, 1, 5),
    deployment_code = project,
    # the sheet's "project" column holds the cruise code, not a project name,
    # and inventing one is not this script's job (Decision 13 reasoning)
    project_name = NA_character_,
    # a towed cruise has no site in the moored sense (Decision 13)
    site_code = NA_character_,
    monitoring_start_datetime = stamp_utc(monitoring_start_datetime),
    monitoring_end_datetime = stamp_utc(monitoring_end_datetime),
    deployment_platform_type_code = "TOWED_ARRAY",
    deployment_platform_id = NA_character_,
    deployment_water_depth_m = NA_real_,
    dynamic_management_platform = NA,
    deployment_url = NA_character_,
    # the hydrophone model is published as the device type so that
    # instrument_type is unchanged by the conversion (Decision 11); there is no
    # separate device identifier in the source
    recording_device_code = NA_character_,
    # continuous recording, recorded as the word rather than a duty cycle
    recording_duration_secs = NA_real_,
    recording_interval_secs = NA_real_,
    recording_bit_depth = NA_integer_,
    recording_n_channels = NA_integer_,
    recording_timezone = "UTC",
    recording_device_depth_m = NA_real_,
    points_of_contact = case_when(
      data_poc_name == "Danielle Cholewiak, Annamaria DeAngelis" ~
        "Danielle Cholewiak <danielle.cholewiak@noaa.gov>, Annamaria DeAngelis <annamaria.deangelis@noaa.gov>",
      data_poc_name == "Melissa Soldevilla, Annamaria DeAngelis" ~
        "Melissa Soldevilla <melissa.soldevilla@noaa.gov>, Annamaria DeAngelis <annamaria.deangelis@noaa.gov>",
      TRUE ~ NA_character_
    ),
    project_funding = NA_character_
  ) |>
  left_join(recordings, by = "deployment_code") |>
  left_join(deployment_positions, by = "deployment_code") |>
  transmute(
    deployment_organization_code,
    deployment_code,
    project_name,
    site_code,
    monitoring_start_datetime,
    monitoring_end_datetime,
    deployment_platform_type_code,
    deployment_platform_id,
    deployment_water_depth_m,
    # for mobile platforms PARS takes the deployment position to be the start
    # of the track
    deployment_latitude = latitude,
    deployment_longitude = longitude,
    dynamic_management_platform,
    deployment_url,
    recording_device_code,
    recording_device_type_code = device_type_code,
    recording_duration_secs,
    recording_interval_secs,
    recording_sample_rate_khz = sampling_rate_hz / 1000,
    recording_bit_depth,
    recording_n_channels,
    recording_timezone,
    recording_device_depth_m,
    points_of_contact,
    project_funding
  ) |>
  arrange(deployment_code)

stopifnot(
  nrow(metadata) == 11,
  !anyDuplicated(metadata$deployment_code),
  all(!is.na(metadata$deployment_latitude)),
  all(!is.na(metadata$points_of_contact)),
  all(!is.na(metadata$recording_device_type_code)),
  # every deployment must appear in gpsdata: PARS requires positions for mobile
  # platforms, and pars_gpsdata_errors enforces it
  setequal(metadata$deployment_code, unique(gpsdata$deployment_code))
)

# analyses -----------------------------------------------------------------

BEAKED_CODES <- c("BLBW", "GEBW", "MMME", "GOBW", "SOBW", "TRBW", "UNME")

analyses <- metadata_raw |>
  filter(as.logical(analyzed)) |>
  transmute(
    deployment_code = project,
    analysis_code = case_when(
      species == "beaked" ~ "BEAKED_ANALYSIS",
      species == "sperm" ~ "SPERM_ANALYSIS",
      species == "kogia" ~ "KOGIA_ANALYSIS"
    ),
    analysis_sound_source_codes = case_when(
      species == "beaked" ~ str_c(BEAKED_CODES, collapse = ","),
      species == "sperm" ~ "SPWH",
      species == "kogia" ~ "UNKO"
    ),
    analysis_sample_rate_khz = analysis_sampling_rate_hz / 1000,
    analysis_processing_code = case_when(
      qc_data == "post-processed" ~ "POST_PROCESSED",
      qc_data == "real-time monitoring" ~ "REAL_TIME"
    ),
    call_type_code = case_when(
      call_type == "Frequency modulated upsweep" ~ "OD_CLICK_FM",
      call_type == "Narrow band high frequency click" ~ "OD_CLICK_NBHF",
      call_type == "Usual click" ~ "SPWH_USC"
    ),
    # all three analyses are click detection (Decision 12)
    analysis_detector_code = "PAMGUARD_CLICK",
    analysis_protocol_reference = protocol_reference
  )

# the HB1603 sperm analysis is absent from the analysed rows of the workbook and
# was carried as a hand-built record in towed.R; it becomes an ordinary row here
stopifnot(
  nrow(filter(
    analyses, deployment_code == "NEFSC_HB1603",
    analysis_code == "SPERM_ANALYSIS"
  )) == 0
)

analyses <- bind_rows(
  analyses,
  tibble(
    deployment_code = "NEFSC_HB1603",
    analysis_code = "SPERM_ANALYSIS",
    analysis_sound_source_codes = "SPWH",
    analysis_sample_rate_khz = 96,
    analysis_processing_code = "POST_PROCESSED",
    call_type_code = "SPWH_USC",
    # this one analysis combined the click detector with manual review
    analysis_detector_code = "PAMGUARD_CLICK,MANUAL",
    analysis_protocol_reference = "Westell et al 2022 (In prep)"
  )
) |>
  arrange(deployment_code, analysis_code)

stopifnot(
  nrow(analyses) == 16,
  all(!is.na(analyses$analysis_processing_code)),
  all(!is.na(analyses$call_type_code)),
  all(!is.na(analyses$analysis_protocol_reference))
)

# detection events ---------------------------------------------------------
#
# one reader per source workbook, ported from R/towed/towed-detections.R

read_events <- function (path, code, ...) {
  read_excel(path, ...) |>
    clean_names()
}

det_dir <- file.path(raw_dir, "detections")

# beaked whales: the common shape is a PAMGuard offline-events export
beaked_event_columns <- function (x, code) {
  x |>
    transmute(
      deployment_code = code,
      start = utc,
      end = event_end,
      latitude = tm_latitude1,
      longitude = tm_longitude1,
      species,
      event_type
    )
}

beaked_gu1303 <- read_events(
  file.path(det_dir, "BeakedWhale_data/GU1303_PG_ExportedBWEvents_20160126.xlsx"),
  na = "NULL"
) |>
  beaked_event_columns("SEFSC_GU1303")

beaked_gu1402 <- read_events(
  file.path(det_dir, "BeakedWhale_data/GU1402_OfflineEvents_20160121.xlsx"),
  na = "NULL"
) |>
  beaked_event_columns("NEFSC_GU1402")

beaked_gu1605 <- read_events(
  file.path(det_dir, "BeakedWhale_data/GU1605_PG_OfflineEvents_20190926.xlsx"),
  sheet = "BW_only", range = "A1:AH264", na = "NULL"
) |>
  beaked_event_columns("SEFSC_GU1605")

# GU1803 arrives as three files in two different shapes
beaked_gu1803_gis <- bind_rows(
  read_events(
    file.path(det_dir, "BeakedWhale_data/GU1803_Leg1_BW_detections_4GIS.xlsx"),
    range = "A1:I394", na = "NULL"
  ) |>
    filter(!is.na(species)),
  read_events(
    file.path(det_dir, "BeakedWhale_data/GU1803_Leg2_BW_detections_4GIS.xlsx"),
    range = "A1:F241", na = "NULL"
  )
) |>
  transmute(
    deployment_code = "NEFSC_GU1803",
    start = time_utc,
    end = NA_POSIXct_,
    latitude,
    longitude,
    species,
    event_type = NA_character_
  )

beaked_gu1803_off <- read_events(
  file.path(det_dir, "BeakedWhale_data/GU1803_OffEffort_BW_detections.xlsx"),
  sheet = "forGIS", range = "A1:AZ62", na = "NULL"
) |>
  beaked_event_columns("NEFSC_GU1803")

beaked_hb1303 <- read_events(
  file.path(det_dir, "BeakedWhale_data/HB1303_BW_events_as_of_20170331.xlsx"),
  na = "NULL"
) |>
  beaked_event_columns("NEFSC_HB1303")

beaked_hb1403 <- read_events(
  file.path(det_dir, "BeakedWhale_data/HB1403_OfflineEvents_ALL_20160105_MmMe.xlsx"),
  na = "NULL"
) |>
  beaked_event_columns("NEFSC_HB1403")

beaked_hb1503 <- read_events(
  file.path(det_dir, "BeakedWhale_data/HB1503_OfflineEvents_BW_20160105.xlsx"),
  na = "NULL"
) |>
  beaked_event_columns("NEFSC_HB1503")

# ten sheets, one per leg, with the classification in its own column
beaked_hb1603 <- map_df(seq(1, 10), function (i) {
  read_events(
    file.path(det_dir, "BeakedWhale_data/HB1603_BW_OfflineEvents_20191004.xlsx"),
    sheet = i, na = "NULL"
  ) |>
    select(
      date, utc, event_end, event_type, final_species_classification,
      tm_latitude1, tm_longitude1
    )
}) |>
  filter(!is.na(date)) |>
  transmute(
    deployment_code = "NEFSC_HB1603",
    start = utc,
    end = event_end,
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species = final_species_classification,
    event_type
  )

beaked_hrs1701 <- read_events(
  file.path(det_dir, "BeakedWhale_data/HRS1701_BW_OfflineEvents_20180524.xlsx"),
  sheet = "BW_EventTypes", na = "NULL"
) |>
  beaked_event_columns("NEFSC_HRS1701")

beaked_hrs1910 <- read_events(
  file.path(det_dir, "BeakedWhale_data/HRS1910_RT_detections_edited_AID.xlsx"),
  sheet = "BW_only", na = "NULL"
) |>
  transmute(
    deployment_code = "NEFSC_HRS1910",
    start = date_time_start,
    end = date_time_end,
    latitude = latlong_lat,
    longitude = latlong_lon,
    species = species1_class1,
    event_type = NA_character_
  )

# the submitted species names vary in spelling and punctuation between files
BEAKED_SPECIES_CODES <- c(
  "Blainville's" = "BLBW",
  "Gervais'" = "GEBW",
  "Mm/Me" = "MMME", "MmMe" = "MMME", "MmMe." = "MMME",
  "Gervais'/True's" = "MMME",
  "Cuvier" = "GOBW", "Cuviers" = "GOBW", "Cuvier's" = "GOBW",
  "Goose-beaked" = "GOBW",
  "Sowerby's" = "SOBW",
  "True's" = "TRBW", "True's." = "TRBW",
  "Unid. Mesoplodon" = "UNME"
)

beaked <- bind_rows(
  beaked_gu1303, beaked_gu1402, beaked_gu1605, beaked_gu1803_gis,
  beaked_gu1803_off, beaked_hb1303, beaked_hb1403, beaked_hb1503,
  beaked_hb1603, beaked_hrs1701, beaked_hrs1910
) |>
  # BRAN and DOLP events are other taxa; NA means the file records beaked
  # events only
  filter(is.na(event_type) | event_type %in% c("POBK", "PRBK", "BEAK")) |>
  mutate(
    analysis_code = "BEAKED_ANALYSIS",
    species_code = unname(BEAKED_SPECIES_CODES[as.character(species)])
  ) |>
  select(-species, -event_type)

stopifnot(all(!is.na(beaked$species_code)))

kogia <- read_events(
  file.path(det_dir, "Kogia_data/Kogia Detections.xlsx"),
  sheet = "NBHF_only"
) |>
  transmute(
    deployment_code = if_else(
      str_sub(database, 1, 6) %in% c("GU1605", "GU1303"),
      str_c("SEFSC_", str_sub(database, 1, 6)),
      str_c("NEFSC_", str_sub(database, 1, 6))
    ),
    analysis_code = "KOGIA_ANALYSIS",
    start = utc,
    end = event_end,
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species_code = "UNKO"
  )

sperm_hb1103 <- read_events(
  file.path(det_dir, "SpermWhale_data/HB1103_Pm_revised_events_AW-15Jan2021.xlsx"),
  na = "NaN"
) |>
  transmute(
    deployment_code = "NEFSC_HB1103",
    start = ymd_hms(utc),
    end = ymd_hms(event_end),
    latitude,
    longitude
  ) |>
  # a cluster of fixes at the Newport dock, not at-sea detections
  filter(round(latitude, 5) != 41.53024)

sperm_hb1303 <- read_events(
  file.path(det_dir, "SpermWhale_data/HB1303_Pm_ALL_array_Events.xlsx"),
  na = "NaN"
) |>
  transmute(
    deployment_code = "NEFSC_HB1303",
    start = utc,
    end = event_end,
    latitude = tm_latitude1,
    longitude = tm_longitude1
  )

# HB1603 sperm arrives as a metadata/gps/detections triple in an older
# submission format; positions come from interpolating the supplied track
hb1603_gps <- read_csv(
  file.path(raw_dir, "HB1603-sperm/NEFSC_GPS_20220211.csv"),
  show_col_types = FALSE
) |>
  group_by(DATETIME) |>
  slice(1) |>
  ungroup() |>
  clean_names()

hb1603_latitude <- approxfun(hb1603_gps$datetime, hb1603_gps$latitude, rule = 1)
hb1603_longitude <- approxfun(hb1603_gps$datetime, hb1603_gps$longitude, rule = 1)

sperm_hb1603 <- read_csv(
  file.path(raw_dir, "HB1603-sperm/NEFSC_DETECTIONS_20220211.csv"),
  show_col_types = FALSE
) |>
  clean_names()

stopifnot(all(sperm_hb1603$acoustic_presence == "D"))

sperm_hb1603 <- sperm_hb1603 |>
  transmute(
    deployment_code = "NEFSC_HB1603",
    start = analysis_period_start_datetime,
    end = analysis_period_end_datetime,
    latitude = hb1603_latitude(analysis_period_start_datetime),
    longitude = hb1603_longitude(analysis_period_start_datetime)
  )

sperm <- bind_rows(sperm_hb1103, sperm_hb1303, sperm_hb1603) |>
  mutate(analysis_code = "SPERM_ANALYSIS", species_code = "SPWH")

events <- bind_rows(beaked, kogia, sperm) |>
  mutate(
    # beaked exports record no end time for some events; the current pipeline
    # treats those as instantaneous
    end = coalesce(end, start)
  )

# one HRS1910 event ends 51 seconds before it starts. the current pipeline
# carries the negative duration unnoticed because only the date and position
# are published; PARS validates the ordering, so it is corrected here as the
# transposition it appears to be. the guard keeps the correction from silently
# absorbing a larger problem in a future resubmission
inverted <- which(events$end < events$start)
stopifnot(
  length(inverted) == 1,
  as.numeric(difftime(
    events$start[inverted], events$end[inverted], units = "secs"
  )) < 60
)
events[inverted, c("start", "end")] <- events[inverted, c("end", "start")]

stopifnot(
  nrow(events) == 2930,
  all(!is.na(events$start)),
  all(!is.na(events$latitude) & !is.na(events$longitude)),
  all(events$end >= events$start)
)

# detectiondata ------------------------------------------------------------
#
# PARS has no effort table: a day counts as analysed only if a detection row
# says so. the daily NOT_DETECTED rows below carry the Cruise_dates effort that
# towed_analyses_pacm used to apply at publish time, and they are also what
# lets species expansion resolve the undetected species on a day when one
# beaked species was found

analysis_windows <- cruise_dates |>
  group_by(deployment_code) |>
  summarise(
    analysis_start_datetime = min(date),
    # PARS analysis windows are half-open, so the window ends at midnight
    # following the last analysed day
    analysis_end_datetime = max(date) + 1,
    .groups = "drop"
  )

daily_rows <- analyses |>
  left_join(cruise_dates, by = "deployment_code", relationship = "many-to-many") |>
  transmute(
    deployment_code,
    analysis_code,
    detection_start_datetime = as.POSIXct(date, tz = "UTC"),
    detection_end_datetime = as.POSIXct(date + 1, tz = "UTC"),
    detection_effort_secs = 86400,
    detection_sound_source_code = NA_character_,
    detection_n_validated = NA_integer_,
    detection_result_code = "NOT_DETECTED",
    localization_latitude = NA_real_,
    localization_longitude = NA_real_
  )

event_rows <- events |>
  transmute(
    deployment_code,
    analysis_code,
    detection_start_datetime = start,
    detection_end_datetime = end,
    detection_effort_secs = as.numeric(difftime(end, start, units = "secs")),
    detection_sound_source_code = species_code,
    detection_n_validated = 1L,
    detection_result_code = "DETECTED",
    localization_latitude = latitude,
    localization_longitude = longitude
  )

detectiondata <- bind_rows(daily_rows, event_rows) |>
  inner_join(analyses, by = c("deployment_code", "analysis_code")) |>
  left_join(analysis_windows, by = "deployment_code") |>
  transmute(
    analysis_organization_code = str_sub(deployment_code, 1, 5),
    deployment_code,
    analysis_sound_source_codes,
    analysis_start_datetime = stamp_utc(analysis_start_datetime),
    analysis_end_datetime = stamp_utc(analysis_end_datetime),
    analysis_sample_rate_khz,
    analysis_min_frequency_khz = NA_real_,
    analysis_max_frequency_khz = NA_real_,
    analysis_processing_code,
    analysis_protocol_reference,
    analysis_citations = NA_character_,
    analysis_detector_code,
    analysis_detector_version = NA_character_,
    detection_start_datetime = stamp_utc(detection_start_datetime),
    detection_end_datetime = stamp_utc(detection_end_datetime),
    detection_effort_secs,
    detection_sound_source_code,
    # the call type under analysis, recorded on every row: it is what presence
    # was determined against whether or not anything was detected. this is also
    # what keeps the published call_type unchanged for species with no
    # detections, since pars_analyses_table reads it from the detection rows
    detection_call_type_code = call_type_code,
    detection_n_validated,
    detection_result_code,
    localization_method_code = NA_character_,
    localization_latitude,
    localization_longitude,
    localization_distance_m = NA_real_
  ) |>
  arrange(deployment_code, analysis_sound_source_codes, detection_start_datetime)

stopifnot(
  nrow(detectiondata) == nrow(daily_rows) + nrow(events),
  all(!is.na(detectiondata$detection_result_code)),
  # every event must fall inside its analysis window, which the PARS validator
  # also checks; asserting here points at the source rather than the CSV
  all(detectiondata$detection_start_datetime >= detectiondata$analysis_start_datetime),
  all(detectiondata$detection_end_datetime <= detectiondata$analysis_end_datetime)
)

# write --------------------------------------------------------------------

dir.create(file.path(dir, "clean"), showWarnings = FALSE)

write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(
  gpsdata |> mutate(datetime = stamp_utc(datetime)),
  file.path(dir, "clean/gpsdata.csv"),
  na = ""
)
write_csv(detectiondata, file.path(dir, "clean/detectiondata.csv"), na = "")
