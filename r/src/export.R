# export themes to PACM

library(tidyverse)
library(lubridate)
library(sf)
library(glue)
library(janitor)
library(jsonlite)

# list of themes to export
export_themes <- c(
  "narw",
  "blue",
  "fin",
  "humpback",
  "sei",

  "beaked",
  "kogia",
  "sperm",
  "harbor"
  # "deployments-nefsc"
)


# load --------------------------------------------------------------------

dat <- read_rds("data/themes.rds")

themes <- list()
for (theme in export_themes) {
  themes[[theme]] <- list(
    theme = theme,
    deployments = filter(dat$deployments, theme == !!theme) %>%
      select(-theme),
    detections = filter(dat$detections, theme == !!theme) %>%
      select(-theme)
  )
}


# create deployments ------------------------------------------------------

deployments <- dat$deployments %>% 
  filter(platform_type %in% c("buoy", "mooring")) %>% 
  select(-theme) %>% 
  mutate(
    across(
      c(detection_method, protocol_reference, call_type, analysis_sampling_rate, analyzed, analysis_start_date, analysis_end_date),
      ~ NA
    ),
    across(
      c(analysis_start_date, analysis_end_date),
      as_date
    )
  ) %>% 
  distinct() %>% 
  # filter(!is.na(monitoring_end_datetime)) %>% 
  rowwise() %>% 
  mutate(
    detections = list({
      x <- tibble()
      if (!is.na(monitoring_end_datetime)) {
        x <- tibble(
          date = seq.Date(as_date(monitoring_start_datetime), as_date(monitoring_end_datetime), 1),
          species = NA_character_,
          presence = "d",
          locations = map(id, ~ NULL)
        )
      }
      x
    })
  )

stopifnot(all(!duplicated(deployments$id)))

themes[["deployments"]] <- list(
  theme = "deployments",
  deployments = select(deployments, -detections),
  detections = select(deployments, id, detections) %>% 
    unnest(detections)
)

# write_rds(themes[["deployments"]], "data/themes-deployments-20230707.rds")

# export ------------------------------------------------------------------

for (theme in names(themes)) {
  cat(glue("theme: {theme}"), "\n")
  
  theme_dir <- glue("../public/data/{theme}")
  if (!dir.exists(theme_dir)) {
    cat(glue("creating dir: {theme_dir}"), "\n")
    dir.create(theme_dir)
  }
  
  file_detections <- glue("../public/data/{theme}/detections.csv")
  cat(glue("saving: {file_detections}"), "\n")
  themes[[theme]]$detections %>% 
    relocate(locations, .after = last_col()) %>% 
    mutate(
      locations = map_chr(locations, toJSON, null = "null")
    ) %>%
    write_csv(file_detections, na = "")
  
  file_deployments <- glue("../public/data/{theme}/deployments.json")
  if (file.exists(file_deployments)) {
    cat(glue("deleting: {file_deployments}"), "\n")
    unlink(file_deployments)
  }
  cat(glue("saving: {file_deployments}"), "\n")
  themes[[theme]]$deployments %>%
    mutate(
      across(
        c(monitoring_start_datetime, monitoring_end_datetime, analysis_start_date, analysis_end_date, submission_date),
        format_ISO8601
      )
    ) %>%
    write_sf(file_deployments, driver = "GeoJSON", layer_options = "ID_FIELD=id")
}
