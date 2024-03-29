# combine themes

library(tidyverse)
library(lubridate)
library(sf)
library(glue)
library(janitor)
library(jsonlite)
library(targets)

source("src/functions.R")

platform_types <- c("mooring", "buoy", "slocum", "towed")

if (file.exists("data/themes.rds")) {
  last_rds <- read_rds("data/themes.rds")
} else {
  last_rds <- NULL
}


# load --------------------------------------------------------------------

all_datasets <- list(
  read_rds("data/datasets/towed.rds"),
  read_rds("data/datasets/moored.rds"),
  read_rds("data/datasets/glider.rds"),
  read_rds("data/datasets/nefsc_20211216.rds"),
  read_rds("data/datasets/nefsc_20220211.rds"),
  read_rds("data/datasets/dfo_20211124.rds"),
  read_rds("data/datasets/nydec_20220407.rds"),
  read_rds("data/datasets/ucorn_20220214.rds"),
  read_rds("data/datasets/ucorn_20220302.rds")
)

# merge -------------------------------------------------------------------

deployments_all1 <- map_df(all_datasets, ~ .x$deployments)
detections_all <- map_df(all_datasets, ~ .x$detections)

nefsc_deployments <- read_rds("data/deployment-themes/nefsc.rds")$deployments %>% 
  filter(!id %in% deployments_all1$id) %>% 
  mutate(theme = "deployments")
stopifnot(all(!duplicated(nefsc_deployments$id)))

stopifnot(all(!nefsc_deployments$id %in% deployments_all1$id))

deployments_all <- bind_rows(deployments_all1, nefsc_deployments)


# filter: deployments ---------------------------------------------------

exclude_deployments_platform_type <- deployments_all %>% 
  filter(!platform_type %in% platform_types) %>% 
  as_tibble() %>% 
  select(-geometry) %>% 
  distinct(id, platform_type)

if (nrow(exclude_deployments_platform_type) > 0) {
  cat(glue("excluding {nrow(exclude_deployments_platform_type)} deployments with invalid platform_type (platform_type in [{str_c(sort(unique(exclude_deployments_platform_type$platform_type)), collapse = ', ')}])"), "\n")
}

deployments <- deployments_all %>% 
  anti_join(exclude_deployments_platform_type, by = c("id", "platform_type"))


# filter: detections ------------------------------------------------------

exclude_detections_no_deployment <- detections_all %>% 
  anti_join(deployments, by = c("theme", "id"))

if (nrow(exclude_detections_no_deployment) > 0) {
  cat(glue("excluding {nrow(exclude_detections_no_deployment)} detections with no deployment (id in [{str_c(sort(unique(exclude_detections_no_deployment$id)), collapse = ', ')}])"), "\n")
}

detections <- detections_all %>% 
  semi_join(deployments, by  = c("theme", "id"))

stopifnot(nrow(exclude_detections_no_deployment) == (nrow(detections_all) - nrow(detections)))


# summary -----------------------------------------------------------------

tabyl(detections, presence, theme)
detections %>% 
  left_join(
    tibble(deployments) %>% 
      select(theme, id, platform_type),
    by = c("theme", "id")
  ) %>% 
  tabyl(platform_type, theme)

# no. locations per presence and platform_type
detections %>% 
  left_join(
    tibble(deployments) %>% 
      select(theme, id, platform_type),
    by = c("theme", "id")
  ) %>% 
  mutate(
    n_locations = map_int(locations, ~ if_else(is.null(.), 0L, nrow(.))),
    n_locations = if_else(n_locations > 1, "2+", as.character(n_locations))
  ) %>% 
  tabyl(presence, n_locations, platform_type)

# deployment_type vs platform_type
deployments %>% 
  as_tibble() %>%
  tabyl(platform_type, deployment_type)

# deployment_type vs presence
detections %>% 
  left_join(
    deployments %>% 
      as_tibble() %>% 
      select(theme, id, deployment_type),
    by = c("theme", "id")
  ) %>% 
  tabyl(presence, deployment_type)


# qaqc --------------------------------------------------------------------

qaqc_dataset(deployments, detections)

deployments %>% 
  st_drop_geometry() %>% 
  tabyl(submitter_affiliation, theme)


# diff --------------------------------------------------------------------

current_deployments <- st_drop_geometry(deployments)
last_deployments <- st_drop_geometry(last_rds$deployments)


# added deployments
anti_join(current_deployments, last_deployments, by = c("id")) %>% 
  distinct(id, platform_type, submitter_affiliation) %>% 
  print(n = Inf)

# removed deployments
anti_join(last_deployments, current_deployments, by = c("id")) %>% 
  distinct(id, platform_type)


# export ------------------------------------------------------------------

export <- list(
  config = config::get(),
  deployments = deployments,
  detections = detections
)

# save archived backup
write_rds(export, glue("data/archive/themes-{format(now(), \"%Y%m%d%H%M\")}.rds"))
write_rds(export, "data/themes.rds")
