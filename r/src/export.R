# export datasets to web app

library(tidyverse)
library(lubridate)
library(sf)
library(glue)
library(janitor)
library(jsonlite)

towed <- readRDS("data/towed.rds")
moored <- readRDS("data/moored.rds")
glider <- readRDS("data/glider.rds")
nefsc_deployments <- read_rds("data/nefsc-deployments.rds")

df_deployments <- bind_rows(
  towed$deployments,
  glider$deployments,
  moored$deployments,
  nefsc_deployments$deployments
)

df_detections <- bind_rows(
  towed$detections,
  glider$detections,
  moored$detections,
  nefsc_deployments$detections
) %>% 
  left_join(
    df_deployments %>% 
      as_tibble() %>% 
      distinct(id, deployment_type),
    by = "id"
  ) %>% 
  mutate(
    # presence = if_else(presence == "n" & deployment_type == "mobile", "nm", presence) # change presence to nm for mobile when not detected (for hiding on map)
  ) %>% 
  select(-deployment_type)

# detections with no deployments
df_detections %>% 
  distinct(theme, id) %>% 
  anti_join(
    df_deployments,
    by = c("theme", "id")
  )

# deployments with no detections
df_deployments %>% 
  anti_join(
    df_detections %>% 
       distinct(theme, id),
    by = c("theme", "id")
  ) %>% 
  as_tibble()

df_detections %>% 
  tabyl(theme, presence)

# deployment_type = stationary for mooring, buoy
# deployment_type = mobile for slocum, wave, towed
df_deployments %>% 
  as_tibble() %>%
  tabyl(platform_type, deployment_type)

# presence in y, m, n, na for stationary and mobile
df_detections %>% 
  left_join(
    df_deployments %>% 
      as_tibble() %>% 
      select(theme, id, deployment_type),
    by = c("theme", "id")
  ) %>% 
  filter(theme == "narw") %>% 
  tabyl(deployment_type, presence)

export_theme <- function (theme) {
  # theme <- "narw"

  x_detections <- df_detections %>% 
    filter(theme == !!theme) %>% 
    select(-theme)
  
  x_deployments <- df_deployments %>% 
    filter(theme == !!theme) %>% 
    select(-theme)
  
  missing_detections <- setdiff(x_deployments$id, unique(x_detections$id))
  if (length(missing_detections) > 0) {
    warning(glue("Found {length(missing_detections)} deployments without any detections ({str_c(missing_detections, collapse = ', ')}), removing from deployments table"))
    x_deployments <- x_deployments %>% 
      filter(!id %in% missing_detections)
  }
  
  x_stations <- x_deployments %>% 
    filter(deployment_type == "stationary") %>% 
    select(id)
  x_tracks <- x_deployments %>% 
    filter(deployment_type == "mobile") %>% 
    select(id)
  
  missing_deployments <- setdiff(unique(x_detections$id), x_deployments$id)
  if (length(missing_deployments) > 0) {
    warning(glue("Missing {length(missing_deployments)} deployments found in detections ({str_c(missing_deployments, collapse = ', ')}), removing detections"))
    x_detections <- x_detections %>% 
      filter(!id %in% !!missing_deployments)
  }
  
  missing_stations <- setdiff(
    x_deployments %>% 
      filter(deployment_type == "stationary") %>% 
      pull(id),
    x_stations$id
  )
  if (length(missing_stations) > 0) {
    warning(glue("Missing {length(missing_stations)} stations found in deployments ({str_c(missing_stations, collapse = ', ')}), doing nothing"))
  }
  
  missing_tracks <- setdiff(
    x_deployments %>% 
      filter(deployment_type == "mobile") %>% 
      pull(id),
    x_tracks$id
  )
  if (length(missing_tracks) > 0) {
    warning(glue("Missing {length(missing_tracks)} tracks found in deployments ({str_c(missing_tracks, collapse = ', ')}), doing nothing"))
  }
  
  if (!dir.exists(file.path("../public/data/", theme))) {
    cat(glue("Creating theme folder: {file.path('../public/data/', theme)}"), "\n")
    dir.create(file.path('../public/data/', theme))
  }
  
  x_detections %>% 
    relocate(locations, .after = last_col()) %>%
    mutate(
      locations = map_chr(locations, toJSON, null = 'null')
    ) %>%
    write_csv(file.path("../public/data/", theme, "detections.csv"), na = "")
  
  if (file.exists(file.path("../public/data/", theme, "deployments.json"))) {
    unlink(file.path("../public/data/", theme, "deployments.json"))
  }
  x_deployments %>%
    mutate_at(vars(monitoring_start_datetime, monitoring_end_datetime, analysis_start_date, analysis_end_date, submission_date), format_ISO8601) %>% 
    write_sf(file.path("../public/data/", theme, "deployments.json"), driver = "GeoJSON", layer_options = "ID_FIELD=id")
}

export_theme("narw")
export_theme("fin")
export_theme("blue")
export_theme("humpback")
export_theme("sei")
export_theme("beaked")
export_theme("kogia")
export_theme("sperm")
export_theme("nefsc-deployments")


# demo theme --------------------------------------------------------------
# 
# demo_deployments <- bind_rows(
#   df_deployments %>% 
#     filter(
#       theme == "narw",
#       id %in% c(
#         # "NEFSC_NC_201310_CH2_2",                         # moored | detected
#         # "DUKE_VA_201406_NFC01A_NFC01A",                  # moored | multi-possibly
#         # "MOORS-MURPHY_SCOTIAN_SHELF_200708_PU093_SWGUL", # moored | not detected
#         # "NEFSC_NE_OFFSHORE_201506_WAT_HZ_01_WAT_HZ",     # moored | not analyzed
#         "WHOI_SCOTIAN_SHELF_201509_rb0915_otn200",       # glider | detected/possibly
#         "WHOI_GOM_201812_gom1218_we03",                  # glider | not detected
#         "WHOI_MID-ATLANTIC_202001_hatteras0120_we14"     # glider | not analyzed
#       )
#     )
# ) %>% 
#   mutate(
#     analyzed = if_else(id == "WHOI_MID-ATLANTIC_202001_hatteras0120_we14", FALSE, analyzed)
#   )
# demo_detections <- df_detections %>% 
#   semi_join(
#     demo_deployments,
#     by = c("theme", "id")
#   ) %>% 
#   mutate(
#     presence = case_when(
#       id == "NEFSC_NE_OFFSHORE_201506_WAT_HZ_01_WAT_HZ" ~ "na",
#       id == "WHOI_GOM_201812_gom1218_we03" ~ "nm",
#       id == "WHOI_MID-ATLANTIC_202001_hatteras0120_we14" ~ "na",
#       TRUE ~ presence
#     ),
#     presence = if_else(presence == "nm", "n", presence)
#   ) %>% 
#   mutate(theme = "demo")
# 
# demo_detections_locations <- demo_detections %>% 
#   select(-presence, -date) %>% 
#   unnest(locations) %>% 
#   filter(!id %in% c("WHOI_GOM_201812_gom1218_we03", "WHOI_MID-ATLANTIC_202001_hatteras0120_we14")) %>% 
#   select(id, starts_with("analysis_"), latitude, longitude, presence) %>% 
#   nest(locations = -id)
# 
# demo_detections <- demo_detections %>% 
#   select(-locations) %>% 
#   left_join(demo_detections_locations, by = "id")
# 
# tabyl(demo_detections, id, presence)
# 
# demo_glider_ids <- demo_deployments %>% filter(deployment_type == "mobile") %>% pull(id)
# 
# export_theme("demo", deployments = mutate(demo_deployments, theme = "demo"), detections = demo_detections)
