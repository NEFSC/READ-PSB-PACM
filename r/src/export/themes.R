# export detection themes

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
  "harbor",
  
  "deployments-nefsc"
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


# generate themes ---------------------------------------------------------

narw <- themes$narw
narw$deployments

narw_factor <- tibble(
  factor = c(1, 2, 4, 8)
) |> 
  rowwise() |> 
  mutate(
    theme = str_c("narw-", factor),
    deployments = list({
      for (i in 1:factor) {
        if (i == 1) {
          x <- narw$deployments |> 
            mutate(id = str_c(id, "-", i))
        } else {
          x <- bind_rows(
            x,
            narw$deployments |>
              mutate(id = str_c(id, "-", i))
          )
        }
      }
      x
    }),
    detections = list({
      for (i in 1:factor) {
        if (i == 1) {
          x <- narw$detections |> 
            mutate(id = str_c(id, "-", i))
        } else {
          x <- bind_rows(
            x,
            narw$detections |>
              mutate(id = str_c(id, "-", i))
          )
        }
      }
      x
    })
  )


# export ------------------------------------------------------------------

for (i in 1:nrow(narw_factor)) {
  theme <- narw_factor$theme[[i]]
  deployments <- narw_factor$deployments[[i]]
  detections <- narw_factor$detections[[i]]
  
  cat(glue("theme: {theme}"), "\n")
  
  theme_dir <- glue("../public/data/{theme}")
  if (!dir.exists(theme_dir)) {
    cat(glue("creating dir: {theme_dir}"), "\n")
    dir.create(theme_dir)
  }
  
  file_detections <- glue("../public/data/{theme}/detections.csv")
  cat(glue("saving: {file_detections}"), "\n")
  detections %>% 
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
  deployments %>%
    mutate_at(vars(monitoring_start_datetime, monitoring_end_datetime, analysis_start_date, analysis_end_date, submission_date), format_ISO8601) %>% 
    write_sf(file_deployments, driver = "GeoJSON", layer_options = "ID_FIELD=id")
}


# detections only ---------------------------------------------------------
# use existing number of deployments, only increase detections

narw_factor_detections <- tibble(
  factor = c(1, 2, 4, 8)
) |> 
  rowwise() |> 
  mutate(
    theme = str_c("narw-detect-", factor),
    deployments = list(narw$deployments),
    detections = list({
      for (i in 1:factor) {
        if (i == 1) {
          x <- narw$detections
        } else {
          x <- bind_rows(
            x,
            narw$detections
          )
        }
      }
      x
    })
  )


# export ------------------------------------------------------------------

for (i in 1:nrow(narw_factor_detections)) {
  theme <- narw_factor_detections$theme[[i]]
  deployments <- narw_factor_detections$deployments[[i]]
  detections <- narw_factor_detections$detections[[i]]
  
  cat(glue("theme: {theme}"), "\n")
  
  theme_dir <- glue("../public/data/{theme}")
  if (!dir.exists(theme_dir)) {
    cat(glue("creating dir: {theme_dir}"), "\n")
    dir.create(theme_dir)
  }
  
  file_detections <- glue("../public/data/{theme}/detections.csv")
  cat(glue("saving: {file_detections}"), "\n")
  detections %>% 
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
  deployments %>%
    mutate_at(vars(monitoring_start_datetime, monitoring_end_datetime, analysis_start_date, analysis_end_date, submission_date), format_ISO8601) %>% 
    write_sf(file_deployments, driver = "GeoJSON", layer_options = "ID_FIELD=id")
}
