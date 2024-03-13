# export beaked whale data from moorings

source("_targets.R")
tar_load(pacm_themes)

beaked <- pacm_themes %>% 
  filter(theme == "beaked")
deployments <- beaked$deployments[[1]] %>% 
  filter(platform_type == "mooring")
deployments %>% 
  tabyl(submitter_affiliation)

mapview::mapview(deployments, zcol = "submitter_affiliation")

dfo_deployments <- deployments %>% 
  filter(submitter_affiliation == "DFO Maritimes")

mapview::mapview(dfo_deployments, zcol = "submitter_affiliation")

dfo_detections <- beaked$detections[[1]] %>% 
  filter(id %in% dfo_deployments$id) %>% 
  select(-locations)

dfo_detections_tally <- dfo_detections %>% 
  nest_by(id, .key = "detections") %>% 
  mutate(
    min_year = min(year(detections$date)),
    max_year = max(year(detections$date)),
    species_counts = list({
      detections %>% 
        group_by(species) %>% 
        summarise(
          n = n(),
          n_present = sum(presence == "y")
        )
    }),
  ) %>% 
  print()

dfo_detections_deployment <- dfo_detections_tally %>% 
  select(id, min_year, max_year, species_counts) %>% 
  unnest(species_counts) %>% 
  print()

df_detections_deployment_species <- dfo_detections_deployment %>% 
  left_join(
    dfo_deployments %>% 
      st_drop_geometry() %>% 
      select(id, site_id),
    by = "id"
  ) %>%
  pivot_wider(
    names_from = species,
    values_from = n_present
  )

dfo_detections_site <- df_detections_deployment_species %>% 
  group_by(site_id) %>%
  summarise(
    min_year = min(min_year),
    max_year = max(max_year),
    n = sum(n),
    across(
      c("Cuvier's", "Sowerby's", "Unid. Mesoplodon", "Northern Bottlenose"),
      ~ sum(.x, na.rm = TRUE) / n
    )
  ) %>%
  mutate(years = if_else(min_year == max_year, as.character(min_year), str_c(min_year, max_year, sep = "-"))) %>% 
  select(-min_year, -max_year) %>% 
  print()

# export ------------------------------------------------------------------

out <- dfo_detections_site %>% 
  rename_at(vars(-site_id, -years, -n), ~ str_c("% days ", .x, " present")) %>% 
  left_join(
    dfo_deployments %>% 
      st_drop_geometry() %>% 
      select(site_id, latitude, longitude) %>% 
      distinct() %>% 
      group_by(site_id) %>%
      summarise(across(c(latitude, longitude), mean)),
    by = c("site_id" = "site_id")
  ) %>% 
  relocate(latitude, longitude, years, .after = site_id) %>%
  rename(
    "Site ID" = site_id,
    "Latitude" = latitude,
    "Longitude" = longitude,
    "Years" = years,
    "Total # days" = n
  )

out %>% 
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) %>%
  mapview::mapview(zcol = "Site ID")

out %>% 
  write_csv("notes/20231222/pacm-beaked-dfo-mooring-summary.csv")
