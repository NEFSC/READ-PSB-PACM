library(tidyverse)
library(lubridate)
library(sf)
library(janitor)
library(mapview)

DATA_DIR <- config::get("data_dir")


# load --------------------------------------------------------------------

df_csv <- read_csv(
  file.path(DATA_DIR, "glider", "Glider_detection_data_2020-08-06.csv"),
  col_types = cols(.default = col_character())
) %>% 
  clean_names()

df <- df_csv %>%
  rename_with(
    ~ str_replace(., "_", ":"),
    starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
  ) %>% 
  pivot_longer(
    starts_with(c("narw", "humpback", "sei", "fin", "blue")),
    names_to = c("species", ".value"),
    names_sep = ":",
    values_drop_na = TRUE
  ) %>% 
  transmute(
    deployment_id = unique_id, 
    datetime = ymd_hms(analysis_period_start_datetime), 
    latitude, 
    longitude
  ) %>% 
  distinct() %>% 
  arrange(deployment_id, datetime)


# spatial -----------------------------------------------------------------

sf_points <- df %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

sf_tracks <- sf_points %>% 
  group_by(deployment_id) %>% 
  summarise(
    start = min(datetime),
    end = max(datetime),
    do_union = FALSE
  ) %>% 
  st_cast("LINESTRING")

mapview::mapview(sf_tracks)


# export ------------------------------------------------------------------

list(
  data = df,
  sf = sf_tracks
) %>% 
  write_rds("data/glider/tracks.rds")

