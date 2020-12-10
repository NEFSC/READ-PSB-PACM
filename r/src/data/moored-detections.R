library(tidyverse)
library(lubridate)
library(janitor)

DATA_DIR <- config::get("data_dir")


# load --------------------------------------------------------------------

df_csv <- read_csv(
  file.path(DATA_DIR, "moored", "Moored_detection_data_2020-08-04.csv"),
  col_types = cols(.default = col_character())
) %>% 
  janitor::clean_names()


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
    deployment_id = unique_id,
    species = theme,
    date = as_date(ymd_hms(analysis_period_start_datetime)),
    presence = fct_recode(presence, y = "Detected", n = "Not Detected", m = "Possibly Detected"),
    call_type
  )

summary(df)
tabyl(df, deployment_id, species)
tabyl(df, presence, species)
tabyl(df, call_type, species)

stopifnot(all(
  df %>%
    group_by(theme, deployment_id, species, date) %>% 
    count() %>% 
    pull(n) == 1
))

# export ------------------------------------------------------------------

df %>% 
  saveRDS("data/moored/detections.rds")

