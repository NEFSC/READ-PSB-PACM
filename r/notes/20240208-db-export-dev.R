# export data for new db schema development

source("_targets.R")

OUT_DIR <- "/Users/jeff/git/pacm-gcp/db/seeds/development/data/providers"
DEPLOYMENTS <- c(
  "NEFSC_GOM_202208_MONHEGAN", # mooring
  "NEFSC_MA-RI_202003_NS01",
  "NEFSC_MA-RI_202003_NS02",
  "WHOI_NC_202209_ncch0922_ncch", # buoy
  "WHOI_MA-RI_202202_cox0222_we16", # glider
  "NEFSC_HB1603" # towed
)
THEMES <- c("narw", "humpback", "beaked")

providers <- tribble(
  ~provider_code, ~name,
  "NEFSC", "NOAA NEFSC",
  "WHOI", "Woods Hole Oceanographic Institution"
)

# load --------------------------------------------------------------------

pacm_towed_legs <- tar_read(towed_deployments) %>% 
  distinct(id, cruise_dates) %>% 
  unnest(cruise_dates)

pacm_themes <- tar_read(pacm_themes) %>% 
  filter(theme %in% THEMES)

pacm_deployments_all <- pacm_themes %>% 
  select(theme, deployments) %>% 
  unnest(deployments) %>% 
  select(-geometry) %>% 
  ungroup()
pacm_deployments_all %>% 
  filter(theme == "narw", platform_type == "mooring") %>% view()

pacm_deployments <- pacm_deployments_all %>% 
  filter(
    id %in% DEPLOYMENTS
  ) %>%
  mutate(
    provider_code = case_when(
      data_poc_affiliation == "NOAA NEFSC" ~ "NEFSC",
      data_poc_affiliation == "NOAA/NEFSC" ~ "NEFSC",
      data_poc_affiliation == "Woods Hole Oceanographic Institution" ~ "WHOI",
      TRUE ~ NA_character_
    ),
    recorder_type = instrument_type,
    serial_number = instrument_id
  )
pacm_deployments_towed <- pacm_deployments %>% 
  filter(platform_type == "towed") %>% 
  left_join(
    pacm_towed_legs %>% 
      group_by(id, leg) %>% 
      summarise(
        leg_start = min(date), 
        leg_end = max(date),
        .groups = "drop"
      ),
    by = "id"
  ) %>% 
  mutate(
    id = str_c(id, "_LEG", leg),
    monitoring_start_datetime = as.POSIXct(leg_start),
    monitoring_end_datetime = as.POSIXct(leg_end),
    analysis_start_date = leg_start,
    analysis_end_date = leg_end
  ) %>% 
  select(-leg, -leg_start, -leg_end) %>% 
  print()
pacm_deployments <- pacm_deployments %>% 
  filter(platform_type != "towed") %>%
  bind_rows(pacm_deployments_towed)

tabyl(pacm_deployments, theme, provider_code)
tabyl(pacm_deployments, platform_type, provider_code)

pacm_towed_tracks <- tar_read(towed_tracks)$data %>% 
  filter(id %in% DEPLOYMENTS)
pacm_glider_tracks <- tar_read(glider_tracks)$data %>% 
  filter(id %in% DEPLOYMENTS)
pacm_tracks <- bind_rows(pacm_towed_tracks, pacm_glider_tracks)

tabyl(pacm_tracks, id)

pacm_detections <- pacm_themes %>% 
  select(theme, detections) %>% 
  unnest(detections) %>% 
  filter(
    id %in% pacm_deployments$id
  ) %>% 
  select(-locations) %>% 
  ungroup()


# projects ----------------------------------------------------------------

projects <- pacm_deployments %>% 
  distinct(
    provider_code,
    project_code = project
  ) %>% 
  nest_by(provider_code, .key = "projects")


# sites -------------------------------------------------------------------

sites <- pacm_deployments %>% 
  filter(platform_type %in% c("buoy", "mooring")) %>% 
  distinct(
    provider_code,
    site_code = site_id,
    latitude,
    longitude
  ) %>% 
  nest_by(provider_code, .key = "sites")


# recorders ---------------------------------------------------------------

recorders <- pacm_deployments %>% 
  distinct(
    provider_code,
    recorder_type,
    serial_number
  ) %>% 
  nest_by(provider_code, .key = "recorders")


# detection_analyses ------------------------------------------------------

detections <- pacm_detections %>% 
  transmute(
    deployment_code = id,
    sound_source = case_when(
      theme == "narw" ~ "NARW",
      theme == "humpback" ~ "HUMPBACK",
      theme == "beaked" ~ "BEAKED",
      TRUE ~ NA_character_
    ),
    species = case_when(
      theme == "narw" ~ "NARW",
      theme == "humpback" ~ "HUMPBACK",
      species == "Cuvier's" ~ "GOBW",
      species == "Sowerby's" ~ "SWBW",
      species == "True's" ~ "TRBW",
      species == "Gervais'" ~ "GEBW",
      species == "Gervais'/True's" ~ "MEME",
      TRUE ~ NA_character_
    ),
    date,
    timestamp = as.POSIXct(date),
    value = case_when(
      presence == "y" ~ "D",   # DETECTED
      presence == "n" ~ "ND",  # NOT DETECTED
      presence == "m" ~ "PD",  # POSSIBLY DETECTED
      presence == "na" ~ NA_character_,
      TRUE ~ NA_character_
    )
  ) %>% 
  arrange(deployment_code, sound_source, date) %>% 
  nest_by(deployment_code, sound_source, .key = "values")

detection_analyses <- pacm_deployments %>% 
  transmute(
    deployment_code = id,
    sound_source = case_when(
      theme == "narw" ~ "NARW",
      theme == "humpback" ~ "HUMPBACK",
      theme == "beaked" ~ "BEAKED",
      TRUE ~ NA_character_
    ),
    granularity = "DAY",
    call_library = sound_source,
    software = NA_character_,
    protocol = protocol_reference
  ) %>% 
  left_join(
    detections,
    by = c("deployment_code", "sound_source")
  ) %>% 
  nest_by(deployment_code, .key = "detection_analyses")


# recordings --------------------------------------------------------------

recordings <- pacm_deployments %>% 
  transmute(
    deployment_code = id,
    recorder_type,
    serial_number,
    utc_offset = if_else(soundfiles_timezone == "UTC", 0, NA_real_),
    start = as.POSIXct(analysis_start_date),
    end = as.POSIXct(analysis_end_date),
    sample_rate_hz = sampling_rate_hz,
    bit_depth = NA_real_,
    channels = channel,
    duration_sec = as.numeric(difftime(end, start, units = "secs")),
    interval_sec = NA_real_
  ) %>% 
  distinct() %>% 
  left_join(detection_analyses, by = "deployment_code") %>% 
  nest_by(deployment_code, .key = "recordings")

# tracks ------------------------------------------------------------------

tracks <- pacm_tracks %>% 
  rename(deployment_code = id, timestamp = datetime) %>% 
  arrange(deployment_code, timestamp) %>% 
  mutate(date = as_date(timestamp)) %>% 
  inner_join(pacm_towed_legs, by = c("deployment_code" = "id", "date")) %>% 
  mutate(deployment_code = str_c(deployment_code, "_LEG", leg)) %>%
  select(-date, -leg) %>% 
  nest_by(deployment_code, .key = "values") %>% 
  mutate(
    filename = str_c(deployment_code, "_track.csv"),
    start = min(values$timestamp),
    end = max(values$timestamp)
  ) %>% 
  relocate(values, .after = last_col()) %>% 
  ungroup() %>% 
  nest_by(deployment_code, .key = "gps_tracks")


# deployments -------------------------------------------------------------

deployments <- pacm_deployments %>% 
  transmute(
    provider_code,
    deployment_code = id,
    project_code = project,
    site_code = if_else(platform_type %in% c("mooring", "buoy"), site_id, NA_character_),
    platform_type = case_when(
      platform_type == "slocum" ~ "GLIDER_SLOCUM",
      TRUE ~ toupper(platform_type)
    ),
    water_depth_m = water_depth_meters,
    recorder_depth_m = recorder_depth_meters,
    latitude,
    longitude,
    start = monitoring_start_datetime,
    end = monitoring_end_datetime,
  ) %>% 
  distinct() %>% 
  left_join(tracks, by = "deployment_code") %>%
  left_join(recordings, by = "deployment_code") %>% 
  nest_by(provider_code, .key = "deployments")


# export -------------------------------------------------------------------

export <- providers %>% 
  left_join(sites, by = "provider_code") %>%
  left_join(projects, by = "provider_code") %>%
  left_join(recorders, by = "provider_code") %>%
  left_join(deployments, by = "provider_code")

for (i in 1:nrow(export)) {
  provider <- export[i, ]
  provider_code <- provider$provider_code
  provider_path <- glue::glue("{OUT_DIR}/{provider_code}")
  cat(glue("provider: {provider_code}"), "\n")
  
  if (dir.exists(provider_path)) {
    unlink(provider_path, recursive = TRUE)
  }
  dir.create(provider_path, showWarnings = FALSE, recursive = TRUE)
  
  provider %>% 
    select(-sites, -projects, -recorders, -deployments) %>% 
    as.list() %>% 
    jsonlite::write_json(
      glue::glue("{provider_path}/provider.json"),
      pretty = TRUE, auto_unbox = TRUE, na = NULL
    )

  provider$projects[[1]] %>% 
    jsonlite::write_json(
      glue::glue("{provider_path}/projects.json"),
      pretty = TRUE, auto_unbox = TRUE, na = NULL
    )
  provider$sites[[1]] %>% 
    jsonlite::write_json(
      glue::glue("{provider_path}/sites.json"),
      pretty = TRUE, auto_unbox = TRUE, na = NULL
    )
  provider$recorders[[1]] %>% 
    jsonlite::write_json(
      glue::glue("{provider_path}/recorders.json"),
      pretty = TRUE, auto_unbox = TRUE, na = NULL
    )
  
  provider_deployments <- provider$deployments[[1]]
  if (!is.null(provider_deployments) & (nrow(provider_deployments) > 0)) {
    for (j in 1:nrow(provider_deployments)) {
      provider_deployment <- provider_deployments[j, ]
      deployment_code <- provider_deployment$deployment_code
      deployment_path <- glue::glue("{provider_path}/deployments/{deployment_code}")
      cat(glue("deployment: {deployment_code}"), "\n")
      dir.create(deployment_path, showWarnings = FALSE, recursive = TRUE)
      
      provider_deployment %>% 
        select(-gps_tracks, -recordings) %>% 
        as.list() %>% 
        jsonlite::write_json(
          glue::glue("{deployment_path}/deployment.json"),
          pretty = TRUE, auto_unbox = TRUE, na = NULL
        )
      
      deployment_track <- provider_deployment$gps_tracks[[1]]
      if (!is.null(deployment_track)) {
        deployment_track <- deployment_track %>% 
          as.list()
        deployment_track$values <- deployment_track$values[[1]]
        deployment_track %>%
          jsonlite::write_json(
            glue::glue("{deployment_path}/gps_track.json"),
            pretty = TRUE, auto_unbox = TRUE, na = NULL
          )
      }
      
      deployment_recordings <- provider_deployment$recordings[[1]]
      if (!is.null(deployment_recordings)) {
        for (k in 1:nrow(deployment_recordings)) {
          deployment_recording <- deployment_recordings[k, ]
          recording_code <- glue("{k}-{deployment_recording$recorder_type}")
          recording_path <- glue::glue("{deployment_path}/recordings/{recording_code}")
          dir.create(recording_path, showWarnings = FALSE, recursive = TRUE)
          cat(glue("recording: {recording_code}"), "\n")
          
          deployment_recording %>% 
            select(-detection_analyses) %>% 
            as.list() %>% 
            jsonlite::write_json(
              glue::glue("{recording_path}/recording.json"),
              pretty = TRUE, auto_unbox = TRUE, na = NULL
            )
          
          recording_detection_analyses <- deployment_recording$detection_analyses[[1]]
          dir.create(glue::glue("{recording_path}/detection_analyses"), showWarnings = FALSE, recursive = TRUE)
          if (nrow(recording_detection_analyses) > 0) {
            for (m in 1:nrow(recording_detection_analyses)) {
              recording_detection_analysis <- recording_detection_analyses[m, ]
              analysis_code <- glue(m, "-", recording_detection_analysis$sound_source)
              analysis_path <- glue::glue("{recording_path}/detection_analyses/{analysis_code}")
              dir.create(analysis_path, showWarnings = FALSE, recursive = TRUE)
              
              recording_detection_analysis %>%
                select(-values) %>%
                as.list() %>%
                jsonlite::write_json(
                  glue::glue("{analysis_path}/analysis.json"),
                  pretty = TRUE, auto_unbox = TRUE, na = NULL
                )
              
              recording_detection_analysis$values[[1]] %>%
                jsonlite::write_json(
                  glue::glue("{analysis_path}/values.json"),
                  pretty = TRUE, auto_unbox = TRUE, na = NULL
                )
            }
          }
        }
      }
    }
  }
}
