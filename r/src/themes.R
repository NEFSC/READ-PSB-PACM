# combine themes

library(tidyverse)
library(lubridate)
library(sf)
library(glue)
library(janitor)
library(jsonlite)

platform_types <- c("mooring", "buoy", "slocum", "towed")

# load --------------------------------------------------------------------

towed <- readRDS("data/datasets/towed.rds")
moored <- readRDS("data/datasets/moored.rds")
glider <- readRDS("data/datasets/glider.rds")
nefsc <- readRDS("data/deployment-themes/nefsc.rds")

df_deployments_all <- bind_rows(
  towed$deployments,
  glider$deployments,
  moored$deployments,
  nefsc$deployments
)

df_detections_all <- bind_rows(
  towed$detections,
  glider$detections,
  moored$detections,
  nefsc$detections
)


# filter: deployments ---------------------------------------------------

exclude_deployments_platform_type <- df_deployments_all %>% 
  filter(!platform_type %in% platform_types) %>% 
  as_tibble() %>% 
  select(-geometry) %>% 
  distinct(id, platform_type)

if (nrow(exclude_deployments_platform_type) > 0) {
  cat(glue("excluding {nrow(exclude_deployments_platform_type)} deployments with invalid platform_type (platform_type in [{str_c(sort(unique(exclude_deployments_platform_type$platform_type)), collapse = ', ')}])"), "\n")
}

df_deployments <- df_deployments_all %>% 
  anti_join(exclude_deployments_platform_type, by = c("id", "platform_type"))


# filter: detections ------------------------------------------------------

exclude_detections_no_deployment <- df_detections_all %>% 
  anti_join(df_deployments, by = c("theme", "id"))

if (nrow(exclude_detections_no_deployment) > 0) {
  cat(glue("excluding {nrow(exclude_detections_no_deployment)} detections with no deployment (id in [{str_c(sort(unique(exclude_detections_no_deployment$id)), collapse = ', ')}])"), "\n")
}

df_detections <- df_detections_all %>% 
  semi_join(df_deployments, by  = c("theme", "id"))

stopifnot(nrow(exclude_detections_no_deployment) == (nrow(df_detections_all) - nrow(df_detections)))


# qaqc --------------------------------------------------------------------

# all detections have a deployment
stopifnot(
  df_detections %>% 
    anti_join(
      df_deployments,
      by = c("theme", "id")
    ) %>% 
    nrow() == 0
)

# all deployments have a detection
stopifnot(
  df_deployments %>% 
    anti_join(
      df_detections,
      by = c("theme", "id")
    ) %>% 
    nrow() == 0
)


# summary -----------------------------------------------------------------

# theme vs presence
df_detections %>% 
  tabyl(presence, theme)

# theme vs presence
df_detections %>% 
  left_join(
    df_deployments %>% 
      as_tibble() %>% 
      select(theme, id, platform_type),
    by = c("theme", "id")
  ) %>% 
  tabyl(platform_type, theme)

# deployment_type vs platform_type
df_deployments %>% 
  as_tibble() %>%
  tabyl(platform_type, deployment_type)

# deployment_type vs presence
df_detections %>% 
  left_join(
    df_deployments %>% 
      as_tibble() %>% 
      select(theme, id, deployment_type),
    by = c("theme", "id")
  ) %>% 
  tabyl(presence, deployment_type)


# export ------------------------------------------------------------------

list(
  deployments = df_deployments,
  detections = df_detections
) %>% 
  write_rds("data/themes.rds")
