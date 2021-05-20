library(tidyverse)
library(lubridate)
library(janitor)

files <- config::get("files")


# load --------------------------------------------------------------------

df_csv <- read_csv(
  file.path(files$root, files$moored$detection),
  col_types = cols(.default = col_character())
) %>% 
  clean_names()


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


# summary -----------------------------------------------------------------

tabyl(df, theme)
tabyl(df, species, theme)
tabyl(df, presence, theme)


# export ------------------------------------------------------------------
 
write_rds(df, "data/datasets/moored/detections.rds")