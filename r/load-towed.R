# towed array dataset

library(tidyverse)
library(lubridate)
library(sf)
library(readxl)

FILE_DETECT <- "~/Dropbox/Work/nefsc/transfers/20200326 - towed arrays/"
FILE_META <- "~/Dropbox/Work/nefsc/transfers/20200529 - towed array metadata/Towed_Array_effort_Walker_Website.xlsx"

# metadata ----------------------------------------------------------------

df_projects_bw <- read_excel(
  FILE_META,
  sheet = "BW"
) %>% 
  mutate(species = "beaked")

df_projects_kogia <- read_xlsx(
  FILE_META,
  sheet = "KOGIA"
) %>% 
  mutate(species = "kogia")

stopifnot(identical(names(df_projects_bw), names(df_projects_kogia)))

df_projects <- bind_rows(df_projects_bw, df_projects_kogia) %>% 
  janitor::clean_names() %>% 
  mutate(
    submission_date = as_date(submission_date),
    monitoring_start_datetime = lubridate::parse_date_time(monitoring_start_datetime_oracle, "d-b-y I.M.OS Op"),
    monitoring_end_datetime = lubridate::parse_date_time(monitoring_end_datetime_oracle, "d-b-y I.M.OS Op"),
    sampling_rate_hz = sampling_rate_khz * 1000
  ) %>% 
  select(-ends_with(c("_excel", "_oracle")), -starts_with("analysis_"), -sampling_rate_khz)

# ERROR: columns that vary by project/species include platform_type, qc_data

df_projects <- df_projects %>%
  select(-starts_with("monitoring")) %>% 
  rename(data_poc_name = data_poc) %>% 
  mutate(
    # inconsistent columns by project
    platform_type = case_when(
      platform_type == "Towed Array, tetrahedral + linear" ~ "Towed Array, linear",
      TRUE ~ platform_type
    ),
    qc_data = "UNKNOWN", # glider/moored use "YES"
  ) %>% 
  distinct() %>% 
  left_join(
    # monitoring start/end datetimes
    df_projects %>% 
      group_by(project, species) %>% 
      summarise(
        monitoring_start_datetime = min(monitoring_start_datetime),
        monitoring_end_datetime = max(monitoring_end_datetime),
        .groups = "drop"
      ),
    by = c("project", "species")
  ) %>% 
  mutate(
    # missing columns
    id = project,
    platform_type = "towed",
    platform_id = NA_character_,
    site_id = NA_character_,
    instrument_type = NA_character_,
    instrument_id = NA_character_,
    channel = NA_integer_,
    water_depth_meters = NA_real_,
    recorder_depth_meters = NA_real_
  ) %>% 
  select(id, everything())

stopifnot(all(!duplicated(str_c(df_projects$project, df_projects$species))))

df_projects %>% 
  janitor::tabyl(project, species)

# tracks ------------------------------------------------------------------

df_track_gu1303 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "GU1303_gpsData.xlsx"),
  col_types = "guess"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    echosounders = "ON",
    track_id = "GU1303"
  )

df_track_gu1605 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "GU1605_allGPS_Corrected.xlsx"),
  col_types = "guess"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    echosounders = "OFF",
    track_id = "GU1605"
  )

# TODO: get start/end timestamps in UTC for echosounders
df_track_gu1803 <- list.files(file.path(FILE_DETECT, "ShipTracklines", "GU1803_ShipGPS_EffortAppended_FIXED")) %>% 
  map_df(function (fname) {
    read_xlsx(
      file.path(FILE_DETECT, "ShipTracklines", "GU1803_ShipGPS_EffortAppended_FIXED", fname),
      col_types = "guess"
    ) %>% 
      janitor::clean_names()
  }) %>% 
  rename(utc = date_time_utc) %>% 
  mutate(
    echosounders = if_else(
      utc < ymd_hm("2018-07-31 17:00") | utc > ymd_hm("2018-08-17 15:00"),
      "OFF",
      "ON"
    ),
    track_id = "GU1803"
  ) %>% 
  filter(
    user_field >= 0,
    longitude > -90,
    longitude < -30,
    latitude < 90
  )
summary(df_track_gu1803)

df_track_gu1803 %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>% 
  group_by(track_id) %>% 
  summarise(
    start = min(utc),
    end = max(utc),
    do_union = FALSE
  ) %>% 
  st_cast("LINESTRING") %>% 
  mapview::mapview()

df_track_hb1303 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "HB1303_PG_GPS_ALL_AIedits.xlsx"),
  col_types = "guess"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    track_id = "HB1303"
  )

# TODO: fix HB1403 - 20180725 (GMT) sheet to match others, missing echosounders

# Sheet: 20140725 (GMT)
#    - drop `PC Time`? same as `GpsDate`? (assume so)
#    - does `Recording Effort` column match `MF Rec Effort` or `HF Rec Effort` on other sheets? (set both to Recording Effort)
#    - missing echosounders column (assume NA)
df_track_hb1403_1 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 1,
  col_types = "guess",
  range = "A1:Q28830"
) %>% 
  janitor::clean_names() %>% 
  rename(
    distance_km = distance,
    mf_rec_effort = recording_effort
  ) %>% 
  select(
    -pc_time
  ) %>% 
  mutate(
    hf_rec_effort = mf_rec_effort,
    date = format(as_date(gps_date), "%m/%d/%Y"),
    time = format(gps_date, "%H:%M:%S"),
    echosounders = NA_character_
  )
df_track_hb1403_2 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 2,
  col_types = "guess",
  range = "A1:T86072"
) %>% 
  janitor::clean_names() %>% 
  rename(
    acoustic_effort = effort,
    distance_km = distance
  )
df_track_hb1403_3 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 3,
  col_types = "guess",
  range = "A1:T59256"
) %>% 
  janitor::clean_names() %>% 
  rename(
    distance_km = distance
  )
df_track_hb1403_4 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 4,
  col_types = "guess",
  range = "A1:T30509"
) %>% 
  janitor::clean_names()
df_track_hb1403_5 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 5,
  col_types = "guess",
  range = "A1:T14141"
) %>% 
  janitor::clean_names() %>% 
  rename(echosounders = echsounders)

df_track_hb1403 <- bind_rows(
  df_track_hb1403_1,
  df_track_hb1403_2,
  df_track_hb1403_3,
  df_track_hb1403_4,
  df_track_hb1403_5
) %>% 
  rename(utc = gps_date) %>% 
  mutate(
    date = mdy(date),
    duration = format(duration, "%H:%M:%S"),
    track_id = "HB1403"
  )

df_track_hb1503_1 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "HB1503_20150615_gpsData.xlsx"),
  col_types = "guess"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    utc = mdy_hms(utc),
    utc_milliseconds = parse_number(utc_milliseconds),
    pc_local_time = mdy_hms(pc_local_time),
    pc_time = mdy_hms(pc_time),
    gps_date = mdy_hms(gps_date),
    gps_time = parse_number(gps_time)
  )
df_track_hb1503_2 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "HB1503_Copy of Leg1_gps_June16-18.xlsx"),
  col_types = "guess"
) %>% 
  janitor::clean_names()
df_track_hb1503_3 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "HB1503_Leg2_ShipGPS.xlsx"),
  col_types = "guess"
) %>% 
  janitor::clean_names() %>% 
  select(-night)

df_track_hb1503 <- bind_rows(
  df_track_hb1503_1,
  df_track_hb1503_2,
  df_track_hb1503_3
) %>% 
  mutate(
    echosounders = "OFF",
    track_id = "HB1503"
  )

df_track_hb1603 <- read_xlsx(
  file.path(FILE_DETECT, "ShipTracklines", "HB1603_ship_GPS_EchoAdd_All_legs_combined.xlsx"),
  col_types = c(rep("guess", times = 21), "text")
) %>% 
  janitor::clean_names() %>% 
  rename(echosounders = echosounder) %>% 
  mutate(
    track_id = "HB1603"
  )

df_track_hrs1701 <- read_csv(
  file.path(FILE_DETECT, "ShipTracklines", "HRS1701_Skala_gpsData.csv")
) %>% 
  janitor::clean_names() %>% 
  mutate(
    utc = mdy_hms(utc),
    echosounders = if_else(
      utc < ymd_hm("2017-09-17 00:03") | utc > ymd_hm("2017-09-17 10:05"),
      "OFF",
      "ON"
    ),
    track_id = "HRS1701"
  )

df_tracks_raw <- list(
  df_track_gu1303,
  df_track_gu1605,
  df_track_gu1803,
  df_track_hb1303,
  df_track_hb1403,
  df_track_hb1503,
  df_track_hb1603,
  df_track_hrs1701
) %>% 
  map_df(~ select(., id = track_id, datetime = utc, latitude, longitude, echosounders)) %>% 
  mutate(
    id = if_else(
      id %in% c("GU1605"),
      str_c("SEFSC_", id, sep = ""),
      str_c("NEFSC_", id, sep = "")
    )
  )

df_tracks_hr <- df_tracks %>% 
  mutate(datetime2 = datetime) %>% 
  group_by(project_id = id, datetime = floor_date(datetime, unit = "hour")) %>% 
  summarise(
    # n = n(),
    # start = min(datetime2),
    # end = max(datetime2),
    latitude = median(latitude, na.rm = TRUE),
    longitude = median(longitude, na.rm = TRUE),
    # echosounders = any(echosounders == "ON"),
    .groups = "drop"
  ) %>% 
  mutate(
    id = str_c(project_id, format(datetime, "%Y%m%d%H"), sep = "@")
  )

df_tracks_hr

df_projects %>% 
  anti_join(df_tracks_hr, by = c("id" = "track_id")) %>%
  pull(id)

setdiff(unique(df_tracks$id), unique(df_projects$id))

sf_points <- df_tracks_hr %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

mapview::mapview(sf_points)

sf_tracks <- sf_points %>% 
  group_by(id = project_id) %>% 
  summarise(
    # start = min(start),
    # end = max(end),
    do_union = FALSE
  ) %>% 
  st_cast("LINESTRING")

mapview::mapview(sf_tracks)


# detect: kogia -----------------------------------------------------------

df_kogia_raw <- read_xlsx(file.path(FILE_DETECT, "Kogia_data", "Kogia Detections.xlsx"), sheet = "NBHF_only")

df_kogia <- df_kogia_raw %>% 
  janitor::clean_names() %>% 
  transmute(
    id = str_sub(database, 1, 6),
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species = "kogia",
    presence = "Detected",
    call_type = click_type
  ) %>% 
  mutate(
    id = if_else(
      id %in% c("GU1605"),
      str_c("SEFSC_", id, sep = ""),
      str_c("NEFSC_", id, sep = "")
    )
  )


# detect: beaked ----------------------------------------------------------

df_beaked_gu1303 <- read_xlsx(
  file.path(FILE_DETECT, "BeakedWhale_data", "GU1303_PG_ExportedBWEvents_20160126.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    id = "GU1303"
  )

df_beaked_gu1605 <- read_xlsx(
  file.path(FILE_DETECT, "BeakedWhale_data", "GU1605_PG_OfflineEvents_20190926.xlsx"),
  sheet = "BW_only",
  col_types = "guess",
  range = "A1:AH264",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    id = "GU1605"
  )

df_beaked_gu1803a_1 <- read_xlsx(
  file.path(FILE_DETECT, "BeakedWhale_data", "GU1803_Leg1_BW_detections_4GIS.xlsx"),
  col_types = "guess",
  range = "A1:I394",
  na = "NULL"
) %>% 
  janitor::clean_names()
df_beaked_gu1803a_2 <- read_xlsx(
  file.path(FILE_DETECT, "BeakedWhale_data", "GU1803_Leg2_BW_detections_4GIS.xlsx"),
  col_types = "guess",
  range = "A1:F241",
  na = "NULL"
) %>% 
  janitor::clean_names()

df_beaked_gu1803a <- bind_rows(
  df_beaked_gu1803a_1,
  df_beaked_gu1803a_2
) %>% 
  transmute(
    id = det_id,
    utc = time_utc,
    event = utc, # ERROR: missing event_end
    latitude,
    longitude,
    species
  ) %>% 
  mutate(id = "GU1803")

df_beaked_gu1803b <- read_xlsx(
  file.path(FILE_DETECT, "BeakedWhale_data", "GU1803_OffEffort_BW_detections.xlsx"),
  sheet = "forGIS",
  col_types = "guess",
  range = "A1:AZ62",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(id = "GU1803")

df_beaked_gu1803 <- bind_rows(
  df_beaked_gu1803a,
  df_beaked_gu1803b
)


df_beaked_hb1303 <- read_xlsx(
  file.path(FILE_DETECT, "BeakedWhale_data", "HB1303_BW_events_as_of_20170331.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(id = "HB1303")

df_beaked_hb1403 <- read_xlsx(
  file.path(FILE_DETECT, "BeakedWhale_data", "HB1403_OfflineEvents_ALL_20160105_MmMe.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(id = "HB1403")

df_beaked_hb1503 <- read_xlsx(
  file.path(FILE_DETECT, "BeakedWhale_data", "HB1503_OfflineEvents_BW_20160105.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(id = "HB1503")

df_beaked_hb1603 <- seq(1, 10) %>% 
  map_df(function (i) {
    read_xlsx(
      file.path(FILE_DETECT, "BeakedWhale_data", "HB1603_BW_OfflineEvents_20191004.xlsx"),
      sheet = i,
      col_types = "guess",
      na = "NULL"
    ) %>% 
      janitor::clean_names() %>% 
      select(id, date, utc, utc_milliseconds, event_end, event_type, n_clicks, min_number, best_number, max_number, final_species_classification, echosounder, tm_model_name1, tm_latitude1, tm_longitude1) %>% 
      mutate(sheet = i)
  }) %>% 
  mutate(id = "HB1603") %>%
  filter(!is.na(date))

df_beaked_hrs1701 <- read_xlsx(
  file.path(FILE_DETECT, "BeakedWhale_data", "HRS1701_BW_OfflineEvents_20180524.xlsx"),
  col_types = "guess",
  sheet = "BW_EventTypes",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(id = "HRS1701")

df_beaked <- list(
  df_beaked_gu1303,
  df_beaked_gu1605,
  df_beaked_gu1803,
  df_beaked_hb1303 %>% 
    mutate(
      min_number = NA_real_,
      best_number = NA_real_,
      max_number = NA_real_,
    ),
  df_beaked_hb1403 %>% 
    mutate(
      min_number = NA_real_,
      best_number = NA_real_,
      max_number = NA_real_,
    ),
  df_beaked_hb1503 %>% 
    mutate(
      min_number = NA_real_,
      best_number = NA_real_,
      max_number = NA_real_,
    ),
  df_beaked_hb1603 %>% 
    mutate(species = final_species_classification),
  df_beaked_hrs1701
) %>% 
  map_df(~ select(., id, utc, event_end, latitude = tm_latitude1, longitude = tm_longitude1, event_type, n_clicks, min_number, best_number, max_number, species, tm_model_name = tm_model_name1)) %>% 
  filter(event_type %in% c("POBK", "PRBK", "BEAK")) %>% # ignore BRAN, DOLP
  mutate(
    id = if_else(
      id %in% c("GU1605"),
      str_c("SEFSC_", id, sep = ""),
      str_c("NEFSC_", id, sep = "")
    ),
    species = fct_recode(
      species,
      "Cuvier's" = "Cuvier",
      "Cuvier's" = "Cuviers",
      "Gervais'" = "Gervais",
      "Gervais'/True's" = "Mm/Me",
      "Gervais'/True's" = "MmMe.",
      "Gervais'/True's" = "MmMe",
      "True's" = "True's.",
      "Unid. Mesoplodon" = "Unid Mesoplodon"
    )
  ) %>%
  transmute(
    id,
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude,
    longitude,
    call_type = species,
    species = "beaked",
    presence = "Detected"
  )

summary(df_beaked)
janitor::tabyl(df_beaked$call_type)

unique(df_beaked$call_type) %>% sort

df_beaked %>%
  filter(is.na(latitude)) %>% 
  janitor::tabyl(id)

# detect: merge -----------------------------------------------------------

df_detects_all <- bind_rows(df_kogia, df_beaked) %>% 
  filter(!is.na(latitude)) %>% 
  mutate(
    presence = "y"
  )
df_detects <- df_detects_all %>% 
  mutate(
    date = as_date(analysis_period_start),
    platform_type = "towed"
  )
# select(species, id, date, presence, latitude, longitude)
# 
# df_detects_hr <- df_detects_all %>% 
#   mutate(datetime = floor_date(analysis_period_start, unit = "hour")) %>% 
#   arrange(id, species, datetime) %>% 
#   group_by(id, species, datetime, call_type) %>% 
#   summarise(
#     n_detections = n(),
#     # latitude = first(latitude),
#     # longitude = first(longitude),
#     .groups = "drop"
#   ) %>% 
#   mutate(
#     presence = "y",
#     point_id = str_c(id, format(datetime, "%Y%m%d%H"), sep = "@"),
#     date = as_date(datetime),
#     platform_type = "towed"
#   ) %>% 
#   select(species, point_id, date, presence, call_type, platform_type)
# 
# all(unique(df_detects_hr$point_id) %in% sf_points$id)
# 
# df_detects_hr %>% 
#   filter(
#     !point_id %in% sf_points$id
#   )
# 
# sf_points %>% 
#   filter(project_id == "NEFSC_HB1303") %>% 
#   arrange(datetime) %>% 
#   View()
# 
# df_detects_day %>% 
#   group_by(species, id, date) %>%
#   mutate(n = n()) %>% 
#   filter(n > 1)

summary(df_detects)

stopifnot(all(!is.na(df_detects)))

unique(df_projects$id)
setdiff(unique(df_projects$id), unique(df_detects$id))
setdiff(unique(df_detects$id), unique(df_projects$id))
setdiff(unique(df_tracks$id), unique(df_detects$id))

# export ------------------------------------------------------------------

list(
  projects = df_projects,
  tracks = sf_tracks,
  detects = df_detects
) %>% 
  saveRDS("rds/towed.rds")

