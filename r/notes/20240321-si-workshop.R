# summary stats for 2024 PAM SI workshop

source("_targets.R")

tar_load(pacm_themes)

deployments <- pacm_themes %>% 
  filter(theme != "deployments") %>% 
  select(-detections) %>% 
  unnest(deployments) %>% 
  select(-geometry) %>% 
  ungroup()
detections <- pacm_themes %>% 
  filter(theme != "deployments") %>% 
  select(-deployments) %>% 
  unnest(detections) %>%
  select(-locations) %>% 
  ungroup()
species <- detections %>% 
  mutate(
    species = case_when(
      is.na(species) & theme == "beaked" ~ NA_character_,
      is.na(species) ~ theme,
      TRUE ~ species
    )
  ) %>% 
  filter(!is.na(species))

tabyl(deployments, data_poc_affiliation)

tabyl(deployments, platform_type)

tabyl(species, species) %>% nrow()

deployments %>% 
  distinct(id, platform_type) %>% 
  nrow()

detections %>% 
  nrow()

detections %>% 
  tabyl(presence) %>% 
  adorn_percentages("col")

summary(detections)

detections %>% 
  mutate(year = year(date)) %>% 
  ggplot(aes(year)) +
  geom_histogram(binwidth = 1)

detections %>% 
  filter(presence == "y") %>%
  mutate(
    theme = str_to_title(theme),
    theme = if_else(theme == "Narw", "NARW", theme)
  ) %>% 
  ggplot(aes(date, fct_rev(fct_inorder(theme)))) +
  geom_point(color = "orangered", alpha = 0.25, size = 5) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  labs(y = NULL, x = NULL) +
  theme_bw() +
  theme(text = element_text(size = 16))

