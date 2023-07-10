# compare new and old datasets

source("_targets.R")

# exclude deployments from new external submissions
exclude_deployment_ids <- c(
  external_metadata %>% 
    filter(id %in% c("DFOCA_20230322", "SEFSC_20221223", "JASCO_20230505")) %>% 
    pull(UNIQUE_ID) %>% 
    unique(),
  external_detectiondata %>% 
    filter(id %in% c("DFOCA_20230322", "SEFSC_20221223", "JASCO_20230505")) %>% 
    pull(UNIQUE_ID) %>% 
    unique()
) %>% 
  unique()

old <- read_rds("data/themes.rds")
old_deployments <- old$deployments %>% 
  filter(theme != "deployments") %>% 
  bind_rows(
    read_rds("data/themes-deployments-20230707.rds")$deployments %>% 
      mutate(theme = "deployments")
  )
old_detections <- old$detections %>% 
  filter(theme != "deployments") %>% 
  bind_rows(
    read_rds("data/themes-deployments-20230707.rds")$detections %>% 
      mutate(theme = "deployments") %>% 
      st_drop_geometry()
  )

new <- tar_read(pacm_themes)
new_deployments <- new %>% 
  select(theme, deployments) %>% 
  ungroup() %>% 
  unnest(deployments) %>% 
  filter(!id %in% exclude_deployment_ids, theme != "minke") %>% 
  st_as_sf()
new_detections <- new %>% 
  select(theme, detections) %>% 
  ungroup() %>% 
  unnest(detections) %>%
  filter(!id %in% exclude_deployment_ids, theme != "minke")

setdiff(unique(new_deployments$id), unique(old_deployments$id))
setdiff(unique(old_deployments$id), unique(new_deployments$id))

# old deployments not found in new deployments
# OK: these were merged into one cruise deployment (like other towed arrays)
st_drop_geometry(old_deployments) %>% 
  anti_join(st_drop_geometry(new_deployments), by = "id")

# new deployments not found in old deployments
# OK: non-NEFSC deployments that were not analyzed (no detections)
st_drop_geometry(new_deployments) %>% 
  anti_join(st_drop_geometry(old_deployments), by = "id")

old_deployments_diff <- st_drop_geometry(old_deployments) %>% 
  semi_join(st_drop_geometry(new_deployments), by = c("theme", "id")) %>% 
  arrange(theme, id) %>% 
  mutate(
    analysis_sampling_rate_hz = coalesce(analysis_sampling_rate_hz, analysis_sampling_rate),
    soundfiles_timezone = case_when(
      soundfiles_timezone == "UTC+0" ~ "UTC",
      TRUE ~ soundfiles_timezone
    ),
    qc_data = case_when(
      qc_data == "Archival" ~ "ARCHIVAL",
      TRUE ~ qc_data
    )
  ) %>% 
  select(-analysis_sampling_rate)
  
new_deployments_diff <- st_drop_geometry(new_deployments) %>% 
  semi_join(st_drop_geometry(old_deployments), by = c("theme", "id")) %>% 
  arrange(theme, id)

bind_rows(
  old = old_deployments_diff,
  new = new_deployments_diff,
  .id = "dataset"
) %>% 
  # filter(theme == "narw") %>% 
  # filter(id == "CORNELL_MD_2013_DEP1_A1") %>% vi
  # filter(id == "FCH_2018_09_HF", theme == "beaked") %>% view()
  tabyl(theme, dataset)

diffdf::diffdf(old_deployments_diff, new_deployments_diff)

bind_rows(
  old_deployments_diff[669,],
  new_deployments_diff[669,]
) %>% 
  view()


old_detections_diff <- old_detections %>%
  select(-locations) %>% 
  arrange(theme, id, date, species)

new_detections_diff <- new_detections %>%
  select(-locations) %>% 
  arrange(theme, id, date, species)

bind_rows(
  old = old_detections_diff,
  new = new_detections_diff,
  .id = "dataset"
) %>%
  # filter(theme == "narw") %>% 
  # filter(id == "CORNELL_MD_2013_DEP1_A1") %>% vi
  # pivot_wider(names_from = "dataset", values_from = "presence") %>%
  # filter(is.na(new))
  # tabyl(theme, dataset)
  tabyl(presence, dataset)

  # filter(new != old)

diffdf::diffdf(old_deployments_diff, new_deployments_diff)

