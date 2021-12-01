library(tidyverse)
library(lubridate)
library(janitor)

files <- config::get("files")

# load --------------------------------------------------------------------

detection_files <- list.files(file.path(files$root, files$dfo$detections), full.names = TRUE)

df_csv_files <- tibble(
  file = detection_files,
  data = map(file, ~ read_csv(.x, col_types = cols(.default = col_character())))
) %>% 
  mutate(file = basename(file))

df_csv <- df_csv_files %>% 
  unnest(data) %>% 
  clean_names()

tabyl(df_csv, unique_id)
tabyl(df_csv, call_type)
tabyl(df_csv, species)
tabyl(df_csv, acoustic_presence)
tabyl(hour(ymd_hms(df_csv$analysis_period_start_datetime))) # all daily

# transform ---------------------------------------------------------------

df_day <- df_csv %>%
  transmute(
    theme = "beaked",
    id = unique_id,
    species = case_when(
      species == "HYAM" ~ "Northern Bottlenose",
      species == "MEBI" ~ "Sowerby's",
      species == "MMME" ~ "Gervais'/True's",
      species == "ZICA" ~ "Cuvier's",
      TRUE ~ "Unknown"
    ),
    date = as_date(ymd_hms(analysis_period_start_datetime)),
    presence = fct_recode(acoustic_presence, y = "D", m = "P", n = "N", na = "M"),
    analysis_period_start_datetime = ymd_hms(analysis_period_start_datetime),
    analysis_period_end_datetime = ymd_hms(analysis_period_end_datetime),
    analysis_period_effort_seconds = parse_number(analysis_period_effort_seconds),
    analysis_sampling_rate_hz = parse_number(analysis_sampling_rate_hz),
    call_type,
    qc_data = qc_processing,
    protocol_reference,
    detection_method
  ) %>% 
  arrange(theme, id, date, species, presence)


# summary -----------------------------------------------------------------

tabyl(df_day, theme)
tabyl(df_day, species, theme)
tabyl(df_day, presence, theme)


# export ------------------------------------------------------------------

df_day %>% 
  write_rds("data/datasets/dfo/detections.rds")
