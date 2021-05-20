library(tidyverse)
library(lubridate)
library(sf)
library(readxl)
library(janitor)
library(mapview)

files <- config::get("files")


# load: cruise dates ------------------------------------------------------

cruise_dates <- read_xlsx(
  file.path(files$root, files$towed$metadata),
  sheet = "Cruise_dates"
) %>% 
  clean_names() %>% 
  mutate(across(c(start, end), as_date)) %>% 
  transmute(
    id = if_else(
      cruise %in% c("GU1303", "GU1605"),
      str_c("SEFSC_", cruise, sep = ""),
      str_c("NEFSC_", cruise, sep = "")
    ),
    start,
    end
  ) %>% 
  arrange(id, start) %>% 
  group_by(id) %>% 
  mutate(leg = row_number()) %>% 
  ungroup() %>% 
  rowwise() %>% 
  mutate(
    date = list(seq.Date(start, end, by = "day"))
  ) %>% 
  unnest(date) %>% 
  select(-start, -end)


# load: GU1303 ------------------------------------------------------------------

df_gu1303 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "GU1303_gpsData.xlsx"),
  col_types = "guess"
) %>% 
  clean_names() %>% 
  transmute(
    id = "SEFSC_GU1303",
    datetime = utc,
    latitude,
    longitude
  )


# load: GU1402 ------------------------------------------------------------------

df_gu1402 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "GU1402_GPS_data.xlsx"),
  col_types = "guess"
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_GU1402",
    datetime = utc,
    latitude,
    longitude
  )


# load: GU1605 ------------------------------------------------------------------

df_gu1605 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "GU1605_allGPS_Corrected.xlsx"),
  col_types = "guess"
) %>% 
  clean_names() %>% 
  transmute(
    id = "SEFSC_GU1605",
    datetime = utc,
    latitude,
    longitude
  )


# load: GU1803 ------------------------------------------------------------------

df_gu1803 <- list.files(file.path(files$root, files$towed$tracks, "GU1803_ShipGPS_EffortAppended_FIXED")) %>% 
  map_df(function (fname) {
    read_xlsx(
      file.path(files$root, files$towed$tracks, "GU1803_ShipGPS_EffortAppended_FIXED", fname),
      col_types = "guess"
    ) %>% 
      clean_names()
  }) %>% 
  filter(
    user_field >= 0,
    longitude > -90,
    longitude < -30,
    latitude < 90
  ) %>% 
  transmute(
    id = "NEFSC_GU1803",
    datetime = date_time_utc,
    latitude,
    longitude
  )


# load: HB1103 ------------------------------------------------------------------

df_hb1103a <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1103_gpsData.xlsx"),
  col_types = "guess"
) %>% 
  clean_names() %>%
  transmute(
    id = "NEFSC_HB1103",
    datetime = utc,
    latitude,
    longitude
  )
df_hb1103b <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1103_GPS_data_0729-0730.xlsx"),
  col_types = "guess"
) %>% 
  clean_names() %>%
  transmute(
    id = "NEFSC_HB1103",
    datetime = utc,
    latitude,
    longitude
  )

df_hb1103 <- bind_rows(
  df_hb1103a,
  df_hb1103b
)


# load: HB1303 ------------------------------------------------------------------

df_hb1303 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1303_PG_GPS_ALL_AIedits.xlsx"),
  col_types = "guess"
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HB1303",
    datetime = utc,
    latitude,
    longitude
  )


# load: HB1403 ------------------------------------------------------------------

df_hb1403_1 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 1,
  col_types = "guess",
  range = "A1:Q28830"
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HB1403",
    datetime = gps_date,
    latitude,
    longitude
  )
df_hb1403_2 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 2,
  col_types = "guess",
  range = "A1:T86072"
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HB1403",
    datetime = gps_date,
    latitude,
    longitude
  )
df_hb1403_3 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 3,
  col_types = "guess",
  range = "A1:T59256"
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HB1403",
    datetime = gps_date,
    latitude,
    longitude
  )
df_hb1403_4 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 4,
  col_types = "guess",
  range = "A1:T30509"
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HB1403",
    datetime = gps_date,
    latitude,
    longitude
  )
df_hb1403_5 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1403_Completed_GpsData_AIedits.xlsx"),
  sheet = 5,
  col_types = "guess",
  range = "A1:T14141"
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HB1403",
    datetime = gps_date,
    latitude,
    longitude
  )

df_hb1403 <- bind_rows(
  df_hb1403_1,
  df_hb1403_2,
  df_hb1403_3,
  df_hb1403_4,
  df_hb1403_5
)


# load: HB1503 ------------------------------------------------------------------

df_hb1503_1 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1503_20150615_gpsData.xlsx"),
  col_types = "guess"
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HB1503",
    datetime = mdy_hms(utc),
    latitude,
    longitude
  )
df_hb1503_2 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1503_Copy of Leg1_gps_June16-18.xlsx"),
  col_types = "guess"
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HB1503",
    datetime = utc,
    latitude,
    longitude
  )
df_hb1503_3 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1503_Leg2_ShipGPS.xlsx"),
  col_types = "guess"
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HB1503",
    datetime = utc,
    latitude,
    longitude
  )

df_hb1503 <- bind_rows(
  df_hb1503_1,
  df_hb1503_2,
  df_hb1503_3
)


# load: HB1603 ------------------------------------------------------------------

df_hb1603 <- read_xlsx(
  file.path(files$root, files$towed$tracks, "HB1603_ship_GPS_EchoAdd_All_legs_combined.xlsx"),
  col_types = c(rep("guess", times = 21), "text")
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HB1603",
    datetime = utc,
    latitude,
    longitude
  )


# load: HRS1701 -----------------------------------------------------------------

df_hrs1701 <- read_csv(
  file.path(files$root, files$towed$tracks, "HRS1701_Skala_gpsData.csv"),
  col_types = cols(
    Id = col_double(),
    Date_UTC = col_character(),
    UTC = col_character(),
    UTCMilliseconds = col_double(),
    PCLocalTime = col_character(),
    PCTime = col_character(),
    GpsDate = col_character(),
    GPSTime = col_double(),
    Latitude = col_double(),
    Longitude = col_double(),
    Speed = col_double(),
    SpeedType = col_character(),
    Heading = col_double(),
    HeadingType = col_logical(),
    TrueHeading = col_logical(),
    MagneticHeading = col_logical(),
    MagneticVariation = col_double(),
    GPSError = col_double(),
    DataStatus = col_character()
  )
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HRS1701",
    datetime = mdy_hms(utc),
    latitude,
    longitude
  )


# load: HRS1910 -----------------------------------------------------------------

df_hrs1910 <- read_csv(
  file.path(files$root, files$towed$tracks, "HRS1910_ship_GPS.csv"),
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
) %>% 
  clean_names() %>% 
  transmute(
    id = "NEFSC_HRS1910",
    datetime = utc,
    latitude,
    longitude
  )


# merge -------------------------------------------------------------------

df_raw <- bind_rows(
  df_gu1303,
  df_gu1402,
  df_gu1605,
  df_gu1803,
  df_hb1103,
  df_hb1303,
  df_hb1403,
  df_hb1503,
  df_hb1603,
  df_hrs1701,
  df_hrs1910
) %>% 
  arrange(id, datetime)

# aggregate to hourly timesteps using median lat/lon
df_hr <- df_raw %>% 
  group_by(id, datetime = floor_date(datetime, unit = "hour")) %>% 
  summarise(
    latitude = median(latitude, na.rm = TRUE),
    longitude = median(longitude, na.rm = TRUE),
    .groups = "drop"
  )


# assign legs -------------------------------------------------------------

# no legs missing track data
stopifnot(
  cruise_dates %>% 
    anti_join(
      df_hr %>% 
        mutate(date = as_date(datetime)),
      by = c("id", "date")
    ) %>% 
    nrow() == 0
)

df_legs <- df_hr %>% 
  mutate(date = as_date(datetime)) %>% 
  left_join(cruise_dates, by = c("id", "date"))

# track data with missing legs (not included in Cruise Dates)
# represents time when recorders were off (e.g. returning to port)
df_legs %>% 
  filter(is.na(leg)) %>% 
  distinct(id, date)


# spatial -----------------------------------------------------------------

# convert lat/lon to points
sf_points <- df_legs %>% 
  filter(!is.na(leg)) %>% # only include days listed on cruise tab
  filter(
    !(id == "NEFSC_HB1603" & datetime == ymd_hm(201608110000)) # one point at midnight on this day, but doesn't match rest of the day
  ) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

sf_tracks <- sf_points %>% 
  group_by(id, leg) %>% 
  summarise(
    start = min(datetime),
    end = max(datetime),
    do_union = FALSE,
    .groups = "drop_last"
  ) %>% 
  st_cast("LINESTRING") %>% 
  summarise(
    start = min(start),
    end = max(end),
    do_union = TRUE,
    .groups = "drop"
  ) %>% 
  st_cast("MULTILINESTRING")

mapview(sf_points, zcol = "leg")
mapview(sf_tracks, zcol = "id")


# export ------------------------------------------------------------------

list(
  cruise_dates = cruise_dates,
  legs = df_legs,
  raw = df_raw,
  data = df_hr,
  sf = sf_tracks
) %>% 
  write_rds("data/datasets/towed/tracks.rds")

