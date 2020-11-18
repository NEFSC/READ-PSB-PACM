library(tidyverse)
library(lubridate)
library(janitor)

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
  filter(!is.na(presence)) %>% 
  transmute(
    theme = species,
    deployment_id = unique_id,
    species,
    date = as_date(ymd_hms(analysis_period_start_datetime)),
    presence = fct_recode(presence, y = "Detected", n = "Not Detected", m = "Possibly Detected"),
    call_type,
    analysis_period_start_datetime = ymd_hms(analysis_period_start_datetime),
    analysis_period_end_datetime = ymd_hms(analysis_period_end_datetime),
    analysis_period_effort_seconds = parse_number(analysis_period_effort_seconds),
    latitude = parse_number(latitude),
    longitude = parse_number(longitude)
  ) %>% 
  arrange(theme, deployment_id, species, date, analysis_period_start_datetime) %>% 
  nest(locations = c(analysis_period_start_datetime, analysis_period_end_datetime, analysis_period_effort_seconds, latitude, longitude, presence, call_type)) %>% 
  rowwise() %>% 
  mutate(
    presence = case_when(
      "y" %in% locations$presence ~ "y",
      "m" %in% locations$presence ~ "m",
      TRUE ~ "n"
    ),
    call_type = str_c(sort(unique(locations$call_type)), sep = ","),
    locations = list(select(slice_head(locations, n = 1), -presence, -call_type))
  ) %>% 
  ungroup() %>% 
  select(everything(), locations)

summary(select(df, -locations))
tabyl(df, deployment_id, species)
tabyl(df, presence, species)
tabyl(df, call_type, species)

stopifnot(all(
  df %>%
    group_by(theme, deployment_id, species, date) %>% 
    count() %>% 
    pull(n) == 1
))

# one and only one location per row
stopifnot(all(
  df %>%
    pull(locations) %>% 
    map_int(nrow) == 1
))


# export ------------------------------------------------------------------

df %>% 
  saveRDS("data/glider/detections.rds")

