library(tidyverse)
library(lubridate)
library(janitor)

DATA_DIR <- config::get("data_dir")


# load --------------------------------------------------------------------

df_csv <- read_csv(
  file.path(DATA_DIR, "glider", "20201223", "Glider_detection_data_2020-12-23.csv"),
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
  filter(!is.na(presence)) %>% 
  transmute(
    theme = species,
    id = unique_id,
    species = NA_character_,
    date = as_date(ymd_hms(analysis_period_start_datetime)),
    presence = fct_recode(presence, y = "Detected", n = "Not Detected", m = "Possibly Detected"),
    presence = ordered(presence, levels = c("y", "m", "n")), # need to make ordered for filtering first location of each day
    analysis_period_start_datetime = ymd_hms(analysis_period_start_datetime),
    analysis_period_end_datetime = ymd_hms(analysis_period_end_datetime),
    analysis_period_effort_seconds = parse_number(analysis_period_effort_seconds),
    latitude = parse_number(latitude),
    longitude = parse_number(longitude)
  ) %>% 
  arrange(theme, id, species, date, presence, analysis_period_start_datetime) %>% 
  nest(locations = c(analysis_period_start_datetime, analysis_period_end_datetime, analysis_period_effort_seconds, latitude, longitude, presence)) %>% 
  rowwise() %>% 
  mutate(
    presence = case_when(
      "y" %in% locations$presence ~ "y",
      "m" %in% locations$presence ~ "m",
      TRUE ~ "n"
    ),
    locations = list(locations %>% filter(presence %in% c("y", "m")) %>% slice_head(n = 1)) # only show first location if m or y
  ) %>% 
  ungroup() %>% 
  relocate(locations, .after = last_col())

summary(select(df, -locations))
tabyl(df, id, theme)
tabyl(df, species, theme)
tabyl(df, presence, theme)

df %>% 
  mutate(n_locations = map_int(locations, nrow)) %>% 
  tabyl(n_locations, theme, presence)

stopifnot(all(
  df %>%
    group_by(theme, id, species, date) %>% 
    count() %>% 
    pull(n) == 1
))

# zero or one location per row
stopifnot(all(
  df %>%
    pull(locations) %>% 
    map_int(nrow) <= 1
))


# export ------------------------------------------------------------------

df %>% 
  saveRDS("data/glider/detections.rds")

