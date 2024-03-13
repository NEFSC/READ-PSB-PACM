# export development dataset for PACM GCP

source("_targets.R")

THEMES <- c(
  "narw", 
  "humpback", 
  "beaked"
)
PROVIDERS <- c(
  "NOAA NEFSC",
  "NOAA/NEFSC",
  "Woods Hole Oceanographic Institution"
)
IDS <- c(
  # multiple species
  "NEFSC_NC_201310_CH2_2",
  
  # multiple deployments per site and project
  "NEFSC_MA-RI_202003_NS01",
  "NEFSC_MA-RI_202003_NS02",
  "NEFSC_MA-RI_202007_NS01",
  "NEFSC_MA-RI_202007_NS02",
  
  # buoy
  "WHOI_GOM_201810_mdr1018_buoy",
  
  # slocum glider
  "WHOI_MA-RI_202011_cox1120_we16",
  
  # towed
  "NEFSC_GU1803"
)


# load: pacm --------------------------------------------------------------

pacm_deployments <- tar_read(pacm_themes) %>%
  filter(theme != "deployments") %>% 
  select(-detections) %>% 
  unnest(deployments) %>%
  ungroup()


# find ids ----------------------------------------------------------------

pacm_deployments %>% 
  filter(
    theme %in% THEMES,
    data_poc_affiliation %in% PROVIDERS
    # platform_type=="slocum", 
  ) %>% 
  count(data_poc_affiliation, id, platform_type) %>% 
  arrange(desc(n))


# metadata ---------------------------------------------------------------

metadata <- pacm_deployments %>% 
  filter(
    theme %in% THEMES,
    id %in% IDS
  ) %>% 
  mutate(
    deployment_code = id,
    provider_code = case_when(
      data_poc_affiliation %in% c("NOAA NEFSC", "NOAA/NEFSC") ~ "NEFSC",
      data_poc_affiliation == "Woods Hole Oceanographic Institution" ~ "WHOI",
      TRUE ~ data_poc_affiliation
    ),
    project_code = case_when(
      str_starts(project, "NEFSC_NC_201310") ~ "NEFSC_NC_201310",
      str_starts(project, "WHOI_GOM_201810") ~ "WHOI_GOM_201810",
      str_starts(project, "WHOI_MA-RI_202011") ~ "WHOI_MA-RI_202011",
      TRUE ~ project
    ),
    site_code = case_when(
      id == "NEFSC_NC_201310_CH2_2" ~ "NC_2",
      TRUE ~ toupper(site_id)
    ),
    platform_type = case_when(
      platform_type == "slocum" ~ "GLIDER_SLOCUM",
      TRUE ~ toupper(platform_type)
    ),
    recorder_type = instrument_type,
    serial_number = instrument_id
  ) %>% print()


# providers -------------------------------------------------------

projects <- metadata %>% 
  distinct(provider_code, project_code) %>% 
  nest_by(provider_code, .key = "projects") %>% 
  print()

sites <- metadata %>% 
  filter(!is.na(site_code), !is.na(latitude), !is.na(longitude)) %>% 
  distinct(provider_code, site_code, latitude, longitude) %>% 
  nest_by(provider_code, .key = "sites") %>%
  print()

recorders <- metadata %>% 
  distinct(provider_code, recorder_type, serial_number) %>% 
  nest_by(provider_code, .key = "recorders") %>%
  print()

providers <- metadata %>% 
  distinct(provider_code) %>% 
  left_join(projects, by = "provider_code") %>% 
  left_join(sites, by = "provider_code") %>% 
  left_join(recorders, by = "provider_code") %>% 
  print()


# deployments -------------------------------------------------------------

deployments <- metadata %>% 
  transmute(
    deployment_code,
    provider_code,
    project_code, 
    site_code,
    platform_type,
    start = monitoring_start_datetime, 
    end = monitoring_end_datetime, 
    latitude, 
    longitude,
    water_depth_m = water_depth_meters,
    recorder_depth_m = recorder_depth_meters
  ) %>% print()

recordings <- metadata %>% 
  transmute(
    deployment_code,
    sampling_rate_hz,
    channel,
    # interval_sec = duty_cycle_seconds,
    timezone = case_when(
      soundfiles_timezone %in% c("GMT", "UTC") ~ 0,
      TRUE ~ NA_real_
    ),
    recorder_type,
    serial_number
  ) %>% print()

analyses <- metadata %>% 
  transmute(
    id,
    sound_source = toupper(theme),
    # detection_method,
    granularity = "DAY",
    protocol = protocol_reference, 
    # start = analysis_start_date,
    # end = analysis_end_date,
    # qc_data, 
    call_library = sound_source
  ) %>% print()

glider_tracks <- tar_read(glider_tracks)$data %>% 
  filter(id %in% IDS) %>% 
  rename(deployment_code = id, timestamp = datetime) %>% 
  arrange(deployment_code, timestamp) %>% 
  nest_by(deployment_code, .key = "gps_track")

towed_tracks <- tar_read(towed_tracks)$data %>% 
  filter(id %in% IDS) %>% 
  rename(deployment_code = id, timestamp = datetime) %>% 
  arrange(deployment_code, timestamp) %>% 
  nest_by(deployment_code, .key = "gps_track")

tracks <- bind_rows(glider_tracks, towed_tracks) %>% print()

detections <- tar_read(pacm_themes) %>%
  filter(theme %in% THEMES) %>% 
  select(-deployments) %>% 
  unnest(detections) %>%
  filter(id %in% IDS) %>% 
  ungroup() %>% 
  rename(
    deployment_code = id
  ) %>% 
  print()

# TODO: finish bundling detections
# TODO: export to json




moored_deployments <- tar_read(moored_deployments) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>% 
  left_join(moored_ids, by = "id") %>% 
  distinct(
    id, 
    project_code, 
    site_code = site_id, 
    start = monitoring_start_datetime, 
    end = monitoring_end_datetime, 
    water_depth_m = water_depth_meters, 
    recorder_depth_m = recorder_depth_meters,
    latitude, 
    longitude
  ) %>% print()
moored_recorders <- tar_read(moored_deployments) %>%
  filter(id %in% moored_ids$id, theme %in% THEMES) %>%
  distinct(
    id,
    recorder_type = instrument_type,
    serial_number = instrument_id
  ) %>% print()
moored_recordings <- tar_read(moored_deployments) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>% 
  select(
    id, 
    theme, 
    detection_method, 
    protocol_reference, 
    call_type, 
    qc_data, 
    sampling_rate_hz, 
    soundfiles_timezone
  ) %>% print()
moored_analyses <- tar_read(moored_deployments) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>% 
  select(
    id, 
    theme, 
    detection_method, 
    protocol_reference, 
    call_type, 
    qc_data, 
    sampling_rate_hz, 
    soundfiles_timezone
  ) %>% print()
moored_detections <- tar_read(moored_detections) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>%
  select(
    theme,
    id,
    species,
    date,
    presence
  ) %>% print()

# moored/buoy ------------------------------------------------------------------

tar_read(moored_deployments) %>%
  filter(theme %in% THEMES, !is.null(monitoring_end_datetime)) %>%
  # filter(platform_type == "buoy") %>% 
  pull(id) %>%
  unique()

moored_ids <- tribble(
  ~id,                               ~project_code,
  "NEFSC_MA-RI_202001_NS01_NS01",    "NEFSC_MA-RI_202001",
  "NEFSC_MA-RI_202001_NS02_NS02",    "NEFSC_MA-RI_202001",
  "NEFSC_MA-RI_202007_NS02_NS02",    "NEFSC_MA-RI_202007",
  "WHOI_MA-RI_202007_mamv0720_mamv", "WHOI_MA-RI_202007"
)

tar_read(moored_deployments) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>% 
  left_join(moored_ids, by = "id")

moored_projects <- tar_read(moored_deployments) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>% 
  left_join(moored_ids, by = "id") %>% 
  distinct(
    provider_code = data_poc_affiliation, 
    project_code
  ) %>% print()
moored_sites <- tar_read(moored_deployments) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>% 
  distinct(
    provider_code = data_poc_affiliation, 
    site_code = site_id, 
    latitude,
    longitude
  ) %>% print()
moored_deployments <- tar_read(moored_deployments) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>% 
  left_join(moored_ids, by = "id") %>% 
  distinct(
    id, 
    project_code, 
    site_code = site_id, 
    start = monitoring_start_datetime, 
    end = monitoring_end_datetime, 
    water_depth_m = water_depth_meters, 
    recorder_depth_m = recorder_depth_meters,
    latitude, 
    longitude
  ) %>% print()
moored_recorders <- tar_read(moored_deployments) %>%
  filter(id %in% moored_ids$id, theme %in% THEMES) %>%
  distinct(
    id,
    recorder_type = instrument_type,
    serial_number = instrument_id
  ) %>% print()
moored_recordings <- tar_read(moored_deployments) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>% 
  select(
    id, 
    theme, 
    detection_method, 
    protocol_reference, 
    call_type, 
    qc_data, 
    sampling_rate_hz, 
    soundfiles_timezone
  ) %>% print()
moored_analyses <- tar_read(moored_deployments) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>% 
  select(
    id, 
    theme, 
    detection_method, 
    protocol_reference, 
    call_type, 
    qc_data, 
    sampling_rate_hz, 
    soundfiles_timezone
  ) %>% print()
moored_detections <- tar_read(moored_detections) %>% 
  filter(id %in% moored_ids$id, theme %in% THEMES) %>%
  select(
    theme,
    id,
    species,
    date,
    presence
  ) %>% print()


# glider ------------------------------------------------------------------

tar_read(glider_deployments) %>%
  filter(theme %in% THEMES, !is.na(monitoring_end_datetime)) %>%
  left_join(glider_ids, by = "id") %>%
  pull(id)

glider_ids <- tribble(
  ~id,                               ~project_code,
  "WHOI_MA-RI_202111_cox1121_we16", "WHOI_MA-RI_202111"
)

glider_projects <- tar_read(glider_deployments) %>%
  filter(id %in% glider_ids$id, theme %in% THEMES) %>%
  left_join(glider_ids, by = "id") %>%
  distinct(provider_code = data_poc_affiliation, project_code) %>%
  print()
glider_deployments <- tar_read(glider_deployments) %>%
  filter(id %in% glider_ids) %>%
  left_join(glider_ids, by = "id") %>%
  distinct(
    id,
    project_code,
    site_id,
    monitoring_start_datetime,
    monitoring_end_datetime,
    instrument_type,
    instrument_id
  ) %>%
  print()
glider_analyses <- tar_read(glider_deployments) %>%
  filter(id %in% glider_ids) %>%
  select(id, species = theme, detection_method, protocol_reference, call_type, qc_data)
glider_detections <- tar_read(glider_detections)$data %>%
  filter(id %in% glider_ids) %>%
  print()
glider_tracks <- tar_read(glider_tracks)$data %>%
  filter(id %in% glider_ids)

glider <- list(
  projects = glider_projects,
  deployments = glider_deployments,
  analyses = glider_analyses,
  detections = glider_detections,
  tracks = glider_tracks
)
