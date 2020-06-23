# towed array dataset

library(tidyverse)
library(lubridate)
library(readxl)

DATA_DIR <- "~/Dropbox/Work/nefsc/transfers/20200326 - towed arrays/"

# tracks ------------------------------------------------------------------

df_track_gu1303 <- read_xlsx(
  file.path(DATA_DIR, "ShipTracklines", "GU1303_gpsData.xlsx"),
  col_types = "guess"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    echosounders = "ON",
    track_id = "GU1303"
  )

df_track_gu1605 <- read_xlsx(
  file.path(DATA_DIR, "ShipTracklines", "GU1605_allGPS_Corrected.xlsx"),
  col_types = "guess"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    echosounders = "OFF",
    track_id = "GU1605"
  )

# TODO: get start/end timestamps in UTC for echosounders
df_track_gu1803 <- list.files(file.path(DATA_DIR, "ShipTracklines", "GU1803_ShipGPS_EffortAppended_FIXED")) %>% 
  map_df(function (fname) {
    read_xlsx(
      file.path(DATA_DIR, "ShipTracklines", "GU1803_ShipGPS_EffortAppended_FIXED", fname),
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
    user_field >= 0
  )

df_track_hb1303 <- read_xlsx(
  file.path(DATA_DIR, "ShipTracklines", "HB1303_PG_GPS_ALL_AIedits.xlsx"),
  col_types = "guess"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    track_id = "HB1303"
  )

# TODO: fix HB1403 - 20140725 (GMT) sheet to match others, missing echosounders

# Sheet: 20140725 (GMT)
#    - drop `PC Time`? same as `GpsDate`? (assume so)
#    - does `Recording Effort` column match `MF Rec Effort` or `HF Rec Effort` on other sheets? (set both to Recording Effort)
#    - missing echosounders column (assume NA)
df_track_hb1403_1 <- read_xlsx(
  file.path(DATA_DIR, "ShipTracklines", "HB1403_Completed_GpsData_AIedits.xlsx"),
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
  file.path(DATA_DIR, "ShipTracklines", "HB1403_Completed_GpsData_AIedits.xlsx"),
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
  file.path(DATA_DIR, "ShipTracklines", "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 3,
  col_types = "guess",
  range = "A1:T59256"
) %>% 
  janitor::clean_names() %>% 
  rename(
    distance_km = distance
  )
df_track_hb1403_4 <- read_xlsx(
  file.path(DATA_DIR, "ShipTracklines", "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 4,
  col_types = "guess",
  range = "A1:T30509"
) %>% 
  janitor::clean_names()
df_track_hb1403_5 <- read_xlsx(
  file.path(DATA_DIR, "ShipTracklines", "HB1403_Completed_GpsData_AIedits.xlsx"),
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
  file.path(DATA_DIR, "ShipTracklines", "HB1503_20150615_gpsData.xlsx"),
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
  file.path(DATA_DIR, "ShipTracklines", "HB1503_Copy of Leg1_gps_June16-18.xlsx"),
  col_types = "guess"
) %>% 
  janitor::clean_names()
df_track_hb1503_3 <- read_xlsx(
  file.path(DATA_DIR, "ShipTracklines", "HB1503_Leg2_ShipGPS.xlsx"),
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
  file.path(DATA_DIR, "ShipTracklines", "HB1603_ship_GPS_EchoAdd_All_legs_combined.xlsx"),
  col_types = c(rep("guess", times = 21), "text")
) %>% 
  janitor::clean_names() %>% 
  rename(echosounders = echosounder) %>% 
  mutate(
    track_id = "HB1603"
  )

df_track_hrs1701 <- read_csv(
  file.path(DATA_DIR, "ShipTracklines", "HRS1701_Skala_gpsData.csv")
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

df_tracks <- list(
  df_track_gu1303,
  df_track_gu1605,
  df_track_gu1803,
  df_track_hb1303,
  df_track_hb1403,
  df_track_hb1503,
  df_track_hb1603,
  df_track_hrs1701
) %>% 
  map_df(~ select(., track_id, utc, latitude, longitude, echosounders))

summary(df_tracks)
table(df_tracks$track_id, df_tracks$echosounders)

df_tracks %>% 
  group_by(track_id) %>% 
  summarise(
    n = n(),
    start = min(utc),
    end = max(utc),
    duration_days = as.numeric(difftime(end, start, tz = "UTC", units = "days"))
  )

df_tracks_hr <- df_tracks %>% 
  group_by(track_id, utc = floor_date(utc, unit = "hour")) %>% 
  summarise(
    latitude = median(latitude, na.rm = TRUE),
    longitude = median(longitude, na.rm = TRUE),
    echosounders = any(echosounders == "ON")
  ) %>% 
  ungroup()

# kogia -------------------------------------------------------------------

df_kogia_raw <- read_xlsx(file.path(DATA_DIR, "Kogia_data", "Kogia Detections.xlsx"), sheet = "NBHF_only")

df_kogia <- df_kogia_raw %>% 
  janitor::clean_names() %>% 
  select(database, utc, event_end, latitude = tm_latitude1, longitude = tm_longitude1, tm_model_name = tm_model_name1, click_type, n_clicks, min_number, best_number, max_number) %>% 
  mutate(
    min_number = coalesce(min_number, 1),
    best_number = coalesce(best_number, 1),
    max_number = coalesce(max_number, 1),
    track_id = str_sub(database, 1, 6)
  )


# beaked ------------------------------------------------------------------

df_beaked_gu1303 <- read_xlsx(
  file.path(DATA_DIR, "BeakedWhale_data", "GU1303_PG_ExportedBWEvents_20160126.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    track_id = "GU1303"
  )

df_beaked_gu1605 <- read_xlsx(
  file.path(DATA_DIR, "BeakedWhale_data", "GU1605_PG_OfflineEvents_20190926.xlsx"),
  sheet = "BW_only",
  col_types = "guess",
  range = "A1:AH264",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(
    track_id = "GU1605"
  )

df_beaked_gu1803_1 <- read_xlsx(
  file.path(DATA_DIR, "BeakedWhale_data", "GU1803_Leg1_BW_detections_4GIS.xlsx"),
  col_types = "guess",
  range = "A1:I394",
  na = "NULL"
) %>% 
  janitor::clean_names()
df_beaked_gu1803_2 <- read_xlsx(
  file.path(DATA_DIR, "BeakedWhale_data", "GU1803_Leg2_BW_detections_4GIS.xlsx"),
  col_types = "guess",
  range = "A1:F241",
  na = "NULL"
) %>% 
  janitor::clean_names()

df_beaked_gu1803a <- bind_rows(
  df_beaked_gu1803_1,
  df_beaked_gu1803_2
) %>% 
  select(
    id = det_id,
    utc = time_utc,
    latitude,
    longitude,
    species
  ) %>% 
  mutate(track_id = "GU1803")

df_beaked_gu1803b <- read_xlsx(
  file.path(DATA_DIR, "BeakedWhale_data", "GU1803_OffEffort_BW_detections.xlsx"),
  sheet = "forGIS",
  col_types = "guess",
  range = "A1:AZ62",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(track_id = "GU1803")

df_beaked_hb1303 <- read_xlsx(
  file.path(DATA_DIR, "BeakedWhale_data", "HB1303_BW_events_as_of_20170331.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(track_id = "HB1303")

df_beaked_hb1403 <- read_xlsx(
  file.path(DATA_DIR, "BeakedWhale_data", "HB1403_OfflineEvents_ALL_20160105_MmMe.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(track_id = "HB1403")

df_beaked_hb1503 <- read_xlsx(
  file.path(DATA_DIR, "BeakedWhale_data", "HB1503_OfflineEvents_BW_20160105.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(track_id = "HB1503")

df_beaked_hb1603 <- seq(1, 10) %>% 
  map_df(function (i) {
    read_xlsx(
      file.path(DATA_DIR, "BeakedWhale_data", "HB1603_BW_OfflineEvents_20191004.xlsx"),
      sheet = i,
      col_types = "guess",
      na = "NULL"
    ) %>% 
      janitor::clean_names() %>% 
      select(id, date, utc, utc_milliseconds, event_end, event_type, n_clicks, min_number, best_number, max_number, final_species_classification, echosounder, tm_model_name1, tm_latitude1, tm_longitude1)
  }) %>% 
  mutate(track_id = "HB1603")

df_beaked_hrs1701 <- read_xlsx(
  file.path(DATA_DIR, "BeakedWhale_data", "HRS1701_BW_OfflineEvents_20180524.xlsx"),
  col_types = "guess",
  sheet = "BW_EventTypes",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  mutate(track_id = "HRS1701")

# TODO: add GU1803 Leg 1 and Leg 2
df_beaked <- list(
  df_beaked_gu1303,
  df_beaked_gu1605,
  # df_beaked_gu1803a,
  df_beaked_gu1803b,
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
  map_df(~ select(., track_id, utc, event_end, latitude = tm_latitude1, longitude = tm_longitude1, event_type, n_clicks, min_number, best_number, max_number, species, tm_model_name = tm_model_name1)) %>% 
  mutate(
    species = fct_recode(
      species,
      "Cuvier's" = "Cuvier",
      "Cuvier's" = "Cuviers",
      "Gervais'" = "Gervais",
      "MmMe" = "Mm/Me",
      "MmMe" = "MmMe.",
      "True's" = "True's.",
      "Unid. Mesoplodon" = "Unid Mesoplodon"
    )
  )




# export ------------------------------------------------------------------

list(
  tracks = df_tracks_hr,
  kogia = df_kogia,
  beaked = df_beaked
) %>% 
  saveRDS("rds/towed-arrays.rds")

