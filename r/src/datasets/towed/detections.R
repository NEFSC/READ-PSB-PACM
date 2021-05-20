library(tidyverse)
library(lubridate)
library(readxl)
library(janitor)

files <- config::get("files")

# load: kogia -------------------------------------------------------------------

df_kogia_raw <- read_xlsx(file.path(files$root, files$towed$detections, "Kogia_data", "Kogia Detections.xlsx"), sheet = "NBHF_only")

df_kogia <- df_kogia_raw %>% 
  janitor::clean_names() %>% 
  transmute(
    theme = "kogia",
    species = NA_character_,
    id = str_sub(database, 1, 6),
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    presence = "y"
  ) %>% 
  mutate(
    id = if_else(
      id %in% c("GU1605", "GU1303"),
      str_c("SEFSC_", id, sep = ""),
      str_c("NEFSC_", id, sep = "")
    )
  )

summary(df_kogia)

# load: beaked ------------------------------------------------------------------

df_beaked_gu1303 <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "GU1303_PG_ExportedBWEvents_20160126.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  transmute(
    id = "SEFSC_GU1303",
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species,
    presence = "y",
    event_type
  )

df_beaked_gu1402 <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "GU1402_OfflineEvents_20160121.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  transmute(
    id = "NEFSC_GU1402",
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species,
    presence = "y",
    event_type
  )

df_beaked_gu1605 <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "GU1605_PG_OfflineEvents_20190926.xlsx"),
  sheet = "BW_only",
  col_types = "guess",
  range = "A1:AH264",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  transmute(
    id = "SEFSC_GU1605",
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species,
    presence = "y",
    event_type
  )

df_beaked_gu1803a_1 <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "GU1803_Leg1_BW_detections_4GIS.xlsx"),
  col_types = "guess",
  range = "A1:I394",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  filter(!is.na(species))
df_beaked_gu1803a_2 <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "GU1803_Leg2_BW_detections_4GIS.xlsx"),
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
    id = "NEFSC_GU1803",
    analysis_period_start = time_utc,
    analysis_period_end = NA_POSIXct_,
    analysis_period_effort_seconds = NA_real_,
    latitude,
    longitude,
    species,
    presence = "y",
    event_type = NA_character_
  )
df_beaked_gu1803b <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "GU1803_OffEffort_BW_detections.xlsx"),
  sheet = "forGIS",
  col_types = "guess",
  range = "A1:AZ62",
  na = "NULL"
) %>% 
  janitor::clean_names() %>%
  transmute(
    id = "NEFSC_GU1803",
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species,
    presence = "y",
    event_type
  )
df_beaked_gu1803 <- bind_rows(
  df_beaked_gu1803a,
  df_beaked_gu1803b
)

df_beaked_hb1303 <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "HB1303_BW_events_as_of_20170331.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  transmute(
    id = "NEFSC_HB1303",
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species,
    presence = "y",
    event_type
  )

df_beaked_hb1403 <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "HB1403_OfflineEvents_ALL_20160105_MmMe.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  transmute(
    id = "NEFSC_HB1403",
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species,
    presence = "y",
    event_type
  )

df_beaked_hb1503 <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "HB1503_OfflineEvents_BW_20160105.xlsx"),
  col_types = "guess",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  transmute(
    id = "NEFSC_HB1503",
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species,
    presence = "y",
    event_type
  )

df_beaked_hb1603 <- seq(1, 10) %>% 
  map_df(function (i) {
    read_xlsx(
      file.path(files$root, files$towed$detections, "BeakedWhale_data", "HB1603_BW_OfflineEvents_20191004.xlsx"),
      sheet = i,
      col_types = "guess",
      na = "NULL"
    ) %>% 
      janitor::clean_names() %>% 
      select(id, date, utc, utc_milliseconds, event_end, event_type, n_clicks, min_number, best_number, max_number, final_species_classification, echosounder, tm_model_name1, tm_latitude1, tm_longitude1) %>% 
      mutate(sheet = i)
  }) %>% 
  filter(!is.na(date)) %>% 
  transmute(
    id = "NEFSC_HB1603",
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species = final_species_classification,
    presence = "y",
    event_type
  )

df_beaked_hrs1701 <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "HRS1701_BW_OfflineEvents_20180524.xlsx"),
  col_types = "guess",
  sheet = "BW_EventTypes",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  transmute(
    id = "NEFSC_HRS1701",
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    species = species,
    presence = "y",
    event_type
  )

df_beaked_hrs1910 <- read_xlsx(
  file.path(files$root, files$towed$detections, "BeakedWhale_data", "HRS1910_RT_detections_edited_AID.xlsx"),
  col_types = "guess",
  sheet = "BW_only",
  na = "NULL"
) %>% 
  janitor::clean_names() %>% 
  transmute(
    id = "NEFSC_HRS1910",
    analysis_period_start = date_time_start,
    analysis_period_end = date_time_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = latlong_lat,
    longitude = latlong_lon,
    species = species1_class1,
    presence = "y",
    event_type = NA_character_
  )


# merge: beaked -----------------------------------------------------------

df_beaked_all <- bind_rows(
  df_beaked_gu1303,
  df_beaked_gu1402,
  df_beaked_gu1605,
  df_beaked_gu1803,
  df_beaked_hb1303,
  df_beaked_hb1403,
  df_beaked_hb1503,
  df_beaked_hb1603,
  df_beaked_hrs1701,
  df_beaked_hrs1910
)

tabyl(df_beaked_all, event_type)

df_beaked <- df_beaked_all %>% 
  filter(
    is.na(event_type) | event_type %in% c("POBK", "PRBK", "BEAK") # ignore BRAN, DOLP (keep NA)
  ) %>% 
  mutate(
    theme = "beaked",
    species = fct_recode(
      species,
      "Cuvier's" = "Cuvier",
      "Cuvier's" = "Cuviers",
      "Gervais'/True's" = "Mm/Me",
      "Gervais'/True's" = "MmMe.",
      "Gervais'/True's" = "MmMe",
      "True's" = "True's."
    )
  ) %>% 
  select(-event_type) %>% 
  select(theme, species, everything())


# qaqc: beaked ---------------------------------------------------------

summary(df_beaked)
tabyl(df_beaked, id, species)
tabyl(df_beaked, id, presence)
tabyl(df_beaked, species, presence)

# missing detection coordinates
stopifnot(
  df_beaked %>%
    select(theme, id, latitude, longitude) %>% 
    complete.cases() %>% 
    all()
)


# load: sperm ----------------------------------------------------------------

df_sperm_hb1103 <- read_xlsx(
  file.path(files$root, files$towed$detections, "SpermWhale_data", "HB1103_Pm_revised_events_AW-15Jan2021.xlsx"),
  col_types = "guess",
  na = "NaN"
) %>% 
  janitor::clean_names() %>% 
  transmute(
    id = "NEFSC_HB1103",
    analysis_period_start = ymd_hms(utc),
    analysis_period_end = ymd_hms(event_end),
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = latitude,
    longitude = longitude,
    presence = "y"
  )

df_sperm_hb1303 <- read_xlsx(
  file.path(files$root, files$towed$detections, "SpermWhale_data", "HB1303_Pm_ALL_array_Events.xlsx"),
  col_types = "guess",
  na = "NaN"
) %>% 
  janitor::clean_names() %>% 
  transmute(
    id = "NEFSC_HB1303",
    analysis_period_start = utc,
    analysis_period_end = event_end,
    analysis_period_effort_seconds = as.numeric(difftime(analysis_period_end, analysis_period_start, units = "secs")),
    latitude = tm_latitude1,
    longitude = tm_longitude1,
    presence = "y"
  )


# merge: sperm ------------------------------------------------------------

df_sperm <- bind_rows(
  df_sperm_hb1103,
  df_sperm_hb1303
) %>% 
  mutate(
    theme = "sperm",
    species = NA_character_
  ) %>% 
  relocate(theme, species)


# qaqc: sperm -------------------------------------------------------------

summary(df_sperm)
tabyl(df_sperm, id, species)
tabyl(df_sperm, id, presence)
tabyl(df_sperm, species, presence)

# no missing coordinates
stopifnot(
  df_sperm %>%
    select(id, latitude, longitude) %>% 
    complete.cases() %>% 
    all()
)


# no invalid coordinates
stopifnot(
  df_sperm %>%
    filter(
      latitude < 30 | latitude > 60 | longitude < -80 | longitude > -50
    ) %>% 
    nrow() == 0
)


# merge: all --------------------------------------------------------------

df_all <- bind_rows(df_kogia, df_beaked, df_sperm)

df_inst <- df_all %>%
  transmute(
    theme,
    id,
    species,
    date = as_date(analysis_period_start),
    presence = presence,
    analysis_period_start_datetime = analysis_period_start,
    analysis_period_end_datetime = analysis_period_end,
    analysis_period_effort_seconds,
    latitude,
    longitude
  ) %>% 
  arrange(theme, id, species, date, analysis_period_start_datetime)

# aggregate
df_day <- df_inst %>% 
  nest(locations = c(analysis_period_start_datetime, analysis_period_end_datetime, analysis_period_effort_seconds, latitude, longitude, presence)) %>% 
  rowwise() %>% 
  mutate(
    presence = case_when(
      "y" %in% locations$presence ~ "y",
      "m" %in% locations$presence ~ "m",
      TRUE ~ "n"
    )
  ) %>% 
  ungroup()


# summary -----------------------------------------------------------------

summary(select(df_day, -locations))

tabyl(df_day, id, theme)
tabyl(df_day, presence, theme)

# one value per distinct(theme, id, species, date)
stopifnot(
  all(
    df_day %>%
      count(theme, id, species, date) %>% 
      pull(n) == 1
  )
)

# at least one location per row (all presence = y)
stopifnot(
  all(
    df_day %>%
      pull(locations) %>% 
      map_int(nrow) >= 1
  )
)


# export ------------------------------------------------------------------

list(
  data = df_inst,
  daily = df_day
) %>% 
  write_rds("data/datasets/towed/detections.rds")

