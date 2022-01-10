library(tidyverse)
library(lubridate)
library(janitor)
library(sf)
library(mapview)

files <- config::get("files")


# load --------------------------------------------------------------------

df_csv <- read_csv(
  file.path(files$root, files$glider$detection),
  col_types = cols(.default = col_character())
) %>% 
  clean_names() %>% 
  distinct()


# transform ---------------------------------------------------------------

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
    id = unique_id, 
    datetime = ymd_hms(analysis_period_start_datetime), 
    latitude = parse_number(latitude),
    longitude = parse_number(longitude)
  ) %>% 
  distinct() %>% 
  arrange(id, datetime)


# spatial -----------------------------------------------------------------

sf_points <- df %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

sf_tracks <- sf_points %>% 
  group_by(id) %>% 
  summarise(
    start = min(datetime),
    end = max(datetime),
    do_union = FALSE,
    .groups = "drop"
  ) %>% 
  st_cast("LINESTRING")

mapview::mapview(sf_tracks)


# export ------------------------------------------------------------------

list(
  data = df,
  sf = sf_tracks
) %>% 
  write_rds("data/datasets/glider/tracks.rds")

