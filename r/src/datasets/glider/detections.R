library(tidyverse)
library(lubridate)
library(janitor)

files <- config::get("files")

# load --------------------------------------------------------------------

df_csv <- read_csv(
  file.path(files$root, files$glider$detection),
  col_types = cols(.default = col_character())
) %>% 
  clean_names()


# transform ---------------------------------------------------------------

df_inst <- df_csv %>%
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
    presence = ordered(presence, levels = c("y", "m", "n")), # need to order for filtering first location of each day
    analysis_period_start_datetime = ymd_hms(analysis_period_start_datetime),
    analysis_period_end_datetime = ymd_hms(analysis_period_end_datetime),
    analysis_period_effort_seconds = parse_number(analysis_period_effort_seconds),
    latitude = parse_number(latitude),
    longitude = parse_number(longitude)
  ) %>% 
  arrange(theme, id, species, date, presence, analysis_period_start_datetime)

# aggregate to daily
df_day <- df_inst %>% 
  nest(locations = c(analysis_period_start_datetime, analysis_period_end_datetime, analysis_period_effort_seconds, latitude, longitude, presence)) %>% 
  rowwise() %>% 
  mutate(
    presence = case_when(
      "y" %in% locations$presence ~ "y",
      "m" %in% locations$presence ~ "m",
      TRUE ~ "n"
    ),
    locations = list(
      locations %>%
        filter(presence %in% c("y", "m")) %>%
        mutate(date = as_date(analysis_period_start_datetime)) %>% 
        slice_head(n = 1) # only show first location if m or y
    )
  ) %>% 
  ungroup() %>% 
  relocate(locations, .after = last_col())


# summary -----------------------------------------------------------------

tabyl(df_day, theme)
tabyl(df_day, species, theme)
tabyl(df_day, presence, theme)

# zero locations for presence = n, exactly one location for presence = y or m
df_day %>% 
  mutate(n_locations = map_int(locations, nrow)) %>% 
  tabyl(n_locations, presence)


# export ------------------------------------------------------------------

list(
  data = df_inst,
  daily = df_day
) %>% 
  write_rds("data/datasets/glider/detections.rds")
