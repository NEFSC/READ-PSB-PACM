library(tidyverse)
library(lubridate)
library(janitor)

files <- config::get("files")


# load --------------------------------------------------------------------

df_csv <- read_csv(
  file.path(files$root, files$moored$detection),
  col_types = cols(.default = col_character())
) %>% 
  clean_names() %>% 
  distinct()

df_csv <- df_csv %>% 
  filter(!is.na(analysis_period_start_datetime)) %>% 
  group_by(unique_id, analysis_period_start_datetime) %>% 
  slice(1) %>% 
  ungroup()

stopifnot(
  df_csv %>% 
    transmute(unique_id, date = as_date(ymd_hms(analysis_period_start_datetime))) %>% 
    count(unique_id, date) %>% 
    pull(n) == 1
)

# df_csv %>% 
#   filter(is.na(analysis_period_start_datetime)) %>% 
#   write_csv("~/moored-20220818-detections-missing.csv")
# df_csv_2 %>% 
#   filter(!is.na(analysis_period_start_datetime)) %>% 
#   add_count(unique_id, analysis_period_start_datetime) %>% 
#   filter(n > 1) %>% view
#   write_csv("~/moored-20220818-detections-dups.csv")

# df_csv %>%
#   transmute(unique_id, date = as_date(ymd_hms(analysis_period_start_datetime))) %>%
#   count(unique_id, date) %>%
#   filter(n > 1) %>%
#   select(-n) %>%
#   write_csv("data/qaqc/moored-duplicate-detection-dates.csv")

# transform -------------------------------------------------------------------

df <- df_csv %>%
  rename_with(
    ~ str_replace(., "_", ":"),
    starts_with(c("narw_", "humpback_", "sei_", "fin_", "blue_"))
  ) %>% 
  pivot_longer(
    starts_with(c("narw", "humpback", "sei", "fin", "blue")),
    names_to = c("theme", ".value"),
    names_sep = ":",
    values_drop_na = TRUE
  ) %>%
  filter(!is.na(presence)) %>% 
  transmute(
    theme,
    id = unique_id,
    species = NA_character_,
    date = as_date(ymd_hms(analysis_period_start_datetime)),
    presence = fct_recode(presence, y = "Detected", n = "Not Detected", m = "Possibly Detected")
  )

stopifnot(
  df %>% 
    count(theme, id, species, date) %>% 
    pull(n) == 1
)


# summary -----------------------------------------------------------------

tabyl(df, theme)
tabyl(df, species, theme)
tabyl(df, presence, theme)


# export ------------------------------------------------------------------
 
write_rds(df, "data/datasets/moored/detections.rds")
