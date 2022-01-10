library(tidyverse)
library(lubridate)
library(janitor)
library(glue)
library(sf)

source("src/functions.R")

detections_rds <- read_rds("data/datasets/dfo/detections.rds")
deployments_rds <- read_rds("data/datasets/dfo/deployments.rds")


# analysis period ---------------------------------------------------------

stopifnot(
  all(
    detections_rds %>% 
      distinct(id, analysis_sampling_rate_hz, call_type, detection_method, protocol_reference, qc_data, call_type) %>% 
      count(id) %>% 
      pull(n) == 1
  )
)

analysis_periods <- detections_rds %>% 
  group_by(id) %>% 
  summarise(
    analysis_start_date = min(date),
    analysis_end_date = max(date),
    analysis_sampling_rate = unique(analysis_sampling_rate_hz),
    call_type = unique(call_type),
    detection_method = unique(detection_method),
    protocol_reference = unique(protocol_reference),
    qc_data = unique(qc_data),
    call_type = unique(call_type),
    .groups = "drop"
  ) %>% 
  mutate(
    analyzed = TRUE
  )

deployments_analysis <- deployments_rds %>% 
  inner_join(analysis_periods, by = "id")

# only keep deployments with detection data
stopifnot(nrow(deployments_analysis) == nrow(analysis_periods))

# fill: missing detections ------------------------------------------------
# presence = na for any date missing within the analysis period

# dates over analysis period of each deployment
deployments_dates <- deployments_analysis %>% 
  transmute(
    theme,
    id,
    start = analysis_start_date, 
    end = analysis_end_date,
    n_day = as.numeric(difftime(end, start, unit = "day"))
  ) %>%
  rowwise() %>% 
  mutate(
    date = list(seq.Date(start, end, by = "day"))
  ) %>% 
  unnest(date)

# fill missing detection days with presence = na
# and add empty locations
detections <- deployments_dates %>%  
  select(theme, id, date) %>% 
  full_join(
    detections_rds,
    by = c("theme", "id", "date")
  ) %>% 
  mutate(
    locations = map(theme, ~ NULL)
  ) %>% 
  select(theme, id, date, species, presence, locations)
stopifnot(all(!is.na(detections$presence)))


# qaqc: detections --------------------------------------------------------

# no detections are outside the deployment analysis period
stopifnot(
  detections_rds %>%
    anti_join(deployments_dates, by = c("theme", "id", "date")) %>% 
    nrow() == 0
)

# deployment monitoring days with no detection data (filled with presence = na)
stopifnot(
  deployments_dates %>% 
    anti_join(detections_rds, by = c("id", "date")) %>% 
    distinct(theme, id, start, end, date) %>% 
    select(theme, id = id, analysis_start_date = start, analysis_end_date = end, date) %>%
    arrange(theme, id, analysis_start_date, date) %>% 
    nrow() == 0
)

# none of the deployments are all NA
stopifnot(
  detections %>% 
    count(theme, id, presence) %>% 
    pivot_wider(names_from = "presence", values_from = "n", values_fill = 0) %>% 
    mutate(total = n + na + y + m) %>% 
    filter(na == total) %>% 
    nrow() == 0
)


# summary -----------------------------------------------------------------

tabyl(detections_rds, theme, presence) # before fill
tabyl(detections, theme, presence)     # after fill


# deployments geom --------------------------------------------------------

# no missing id, latitude, longitude
stopifnot(
  all(
    deployments_analysis %>% 
      distinct(id, latitude, longitude) %>% 
      complete.cases()
  )
)

deployments_sf <- deployments_analysis %>% 
  distinct(id, latitude, longitude) %>% 
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

mapview::mapview(deployments_sf, legend = FALSE)

deployments <- deployments_sf %>% 
  left_join(deployments_analysis, by = "id") %>% 
  mutate(deployment_type = "stationary") %>% 
  relocate(deployment_type, geometry, .after = last_col())


# qaqc --------------------------------------------------------------------

qaqc_dataset(deployments, detections)


# export ------------------------------------------------------------------

list(
  deployments = deployments,
  detections = detections
) %>% 
  write_rds("data/datasets/dfo.rds")

