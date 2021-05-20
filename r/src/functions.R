
# constants ---------------------------------------------------------------

multispecies_themes = "beaked"
deployment_themes = "deployments-nefsc"
glider_platform_types = "slocum"


# qaqc --------------------------------------------------------------------

qaqc_dataset <- function (deployments, detections) {
  x_deployments <- tibble(deployments) %>% 
    select(-geometry)
  x_detections <- detections %>% 
    mutate(
      n_locations = map_int(locations, ~ if_else(is.null(.), 0L, nrow(.)))
    ) %>% 
    left_join(
      x_deployments %>% 
        select(theme, id, deployment_type, platform_type),
      by = c("theme", "id")
    )
  
  qaqc_deployments(x_deployments)
  qaqc_detections(x_detections)
}

qaqc_deployments <- function (x) {
  # required columns have no missing values
  stopifnot(
    x %>%
      select(theme, id) %>% 
      complete.cases() %>% 
      all()
  )
}

qaqc_detections <- function (x) {
  # required columns have no missing values
  stopifnot(
    x %>% 
      select(-species, -locations) %>% 
      complete.cases() %>% 
      all()
  )
  
  # no missing species for multispecies theme (beaked) when presence = y or m
  stopifnot(
    x %>% 
      select(-locations) %>% 
      filter(theme %in% multispecies_themes, presence %in% c("y", "m")) %>% 
      complete.cases() %>% 
      all()
  )
  
  # all species missing except beaked
  stopifnot(
    x %>% 
      select(-locations) %>% 
      filter(!theme %in% multispecies_themes) %>% 
      pull(species) %>% 
      is.na() %>% 
      all()
  )
  
  # no locations when deployment_type = mobile and presence = n or na
  stopifnot(
    all(
      x %>% 
        filter(
          deployment_type == "mobile",
          presence %in% c("n", "na")
        ) %>% 
        pull(n_locations) == 0
    )
  )
  
  # at least one location when deployment_type = mobile and presence = y or m
  stopifnot(
    all(
      x %>% 
        filter(
          deployment_type == "mobile",
          presence %in% c("y", "m")
        ) %>% 
        pull(n_locations) > 0
    )
  )
  
  # exactly one location when platform_type is glider and presence = y or m
  stopifnot(
    all(
      x %>% 
        filter(
          platform_type %in% glider_platform_types,
          presence %in% c("y", "m")
        ) %>% 
        pull(n_locations) == 1
    )
  )
  
  # presence = "d" when theme is a deployment theme
  stopifnot(
    all(
      x %>% 
        filter(theme %in% deployment_themes) %>% 
        pull(presence) == "d"
    )
  )
  
  # presence != "d" when theme is not a deployment theme
  stopifnot(
    all(
      x %>% 
        filter(!theme %in% deployment_themes) %>% 
        pull(presence) != "d"
    )
  )
  
  # one row per distinct(theme, id, species, date)
  stopifnot(
    x %>%
      count(theme, id, species, date) %>% 
      pull(n) == 1
  )
  
  # no future dates
  stopifnot(all(x$date <= today()))
  
  # no dates before 2000
  stopifnot(all(x$date >= ymd(20000101)))
}
