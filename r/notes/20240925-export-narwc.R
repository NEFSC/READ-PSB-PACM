source("_targets.R")

tar_load(pacm_themes)

themes <- pacm_themes %>% 
  filter(
    theme %in% c("narw")
  )

deployments <- themes %>% 
  select(theme, deployments) %>% 
  unnest(deployments) %>% 
  # filter(deployment_type == "stationary") %>% 
  select(-geometry) %>% 
  ungroup() %>% 
  select(-theme)
detections <- themes %>% 
  select(theme, detections) %>% 
  unnest(detections) %>%
  ungroup() %>% 
  select(id, date, presence) %>% 
  semi_join(deployments, by = "id")

detections %>% 
  tabyl(presence)

deployments %>% 
  write_csv("~/Dropbox/Work/pacm/transfers/20240925 - narw for narwc/deployments.csv", na = "")

detections %>% 
  write_csv("~/Dropbox/Work/pacm/transfers/20240925 - narw for narwc/detections.csv", na = "")
