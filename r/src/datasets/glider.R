library(tidyverse)
library(lubridate)
library(janitor)
library(glue)
library(sf)

source("src/functions.R")

detections_rds <- read_rds("data/datasets/glider/detections.rds")$daily %>% 
  filter(id != "WHOI_GMX_201705_gmx0517_we10")
deployments_rds <- read_rds("data/datasets/glider/deployments.rds")
tracks_rds <- read_rds("data/datasets/glider/tracks.rds")$sf %>% 
  filter(id != "WHOI_GMX_201705_gmx0517_we10")


detections_rds %>% 
  distinct(id) %>% 
  anti_join(
    deployments_rds %>% 
      distinct(id),
    by = "id"
  )

# analysis period ---------------------------------------------------------
# TODO: add analysis_start_date, analysis_end_date, analyzed to deployments metadata table

analysis_periods <- detections_rds %>% 
  group_by(id) %>% 
  summarise(
    analysis_start_date = min(date),
    analysis_end_date = max(date),
    .groups = "drop"
  ) %>% 
  mutate(
    analyzed = TRUE
  )

deployments_analysis <- deployments_rds %>% 
  left_join(analysis_periods, by = "id")


# qaqc: analysis period ---------------------------------------------------

# analysis periods are the same for each species
stopifnot(
  detections_rds %>%
    group_by(theme, id) %>%
    summarise(
      analysis_start_date = min(date),
      analysis_end_date = max(date),
      .groups = "drop"
    ) %>%
    group_by(id, analysis_start_date, analysis_end_date) %>%
    summarise(
      species = str_c(theme, collapse = ","),
      .groups = "drop"
    ) %>%
    add_count(id) %>%
    filter(n > 1) %>% 
    nrow() == 0
)

# analysis period does not match monitoring period
analysis_periods %>%
  full_join(
    deployments_analysis %>%
      distinct(id, monitoring_start_datetime, monitoring_end_datetime),
    by = "id"
  ) %>%
  mutate(
    same_start = analysis_start_date == as_date(monitoring_start_datetime),
    same_end = analysis_end_date == as_date(monitoring_end_datetime),
    difference_start_days = as.numeric(difftime(analysis_start_date, as_date(monitoring_start_datetime), units = "day")),
    difference_end_days = as.numeric(difftime(as_date(monitoring_end_datetime), analysis_end_date, units = "day")),
    monitoring_start_datetime = format(monitoring_start_datetime, "%Y-%m-%d %H:%M"),
    monitoring_end_datetime = format(monitoring_end_datetime, "%Y-%m-%d %H:%M")
  ) %>%
  select(id, starts_with("monitoring"), starts_with("analysis"), starts_with("difference"), starts_with("same")) %>%
  arrange(id) %>% 
  # filter(!same_start | !same_end) %>% view
  write_csv("data/qaqc/glider-analysis-periods.csv")


# qaqc: deployments -------------------------------------------------------

# deployments with no detections by species
# (all are for theme=blue)
deployments_analysis %>% 
  anti_join(
    detections_rds %>% 
      distinct(id, theme),
    by = c("id", "theme")
  ) %>%
  # tabyl(theme)
  write_csv("data/qaqc/glider-deployments-without-detections.csv")


# exclude deployments withou detections -----------------------------------

# exclude deployments with no detection data for each theme
deployments_analysis2 <- deployments_analysis %>% 
  semi_join(
    detections_rds %>% 
      distinct(id, theme),
    by = c("id", "theme")
  )
tabyl(deployments_analysis2, id, theme)


# fill missing detection days ---------------------------------------------
# since only include detected or possibly, do not fill with NA

deployments_dates <- deployments_analysis2 %>%
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

# detections that are outside the deployment analysis period (none)
stopifnot(
  detections_rds %>%
    anti_join(deployments_dates, by = c("theme", "id", "date")) %>% 
    nrow() == 0
)

# deployment monitoring days with no detection data (add rows with presence="na")
deployments_dates %>% 
  anti_join(detections_rds, by = c("id", "date")) %>% 
  distinct(theme, id, start, end, date) %>% 
  select(theme, id = id, analysis_start_date = start, analysis_end_date = end, date) %>%
  arrange(theme, id, analysis_start_date, date) %>%
  # tabyl(id, theme)
  write_csv("data/qaqc/glider-missing-dates.csv")

detections <- deployments_dates %>%
  select(theme, id, date) %>%
  full_join(
    detections_rds,
    by = c("theme", "id", "date")
  ) %>%
  mutate(
    presence = ordered(coalesce(presence, "na"), levels = c("y", "m", "n", "na"))
  )


# summary -----------------------------------------------------------------

tabyl(detections_rds, theme, presence)
tabyl(detections, theme, presence)


# qaqc: detections --------------------------------------------------------

# none of the deployments are all NA
stopifnot(
  detections %>% 
    count(theme, id, presence) %>% 
    pivot_wider(names_from = "presence", values_from = "n", values_fill = 0) %>% 
    mutate(total = n + na + y + m) %>% 
    filter(na == total) %>% 
    nrow() == 0
)


# add tracks ----------------------------------------------------------------

# no missing tracks or tracks without metadata
stopifnot(identical(sort(tracks_rds$id), sort(unique(deployments_rds$id))))

deployments <- tracks_rds %>% 
  select(-start, -end) %>% 
  inner_join(deployments_analysis2, by = c("id")) %>% 
  mutate(deployment_type = "mobile") %>% 
  relocate(deployment_type, geometry, .after = last_col()) %>% 
  relocate(theme)


# qaqc --------------------------------------------------------------------

qaqc_dataset(deployments, detections)


# export ------------------------------------------------------------------

list(
  deployments = deployments,
  detections = detections
) %>% 
  write_rds("data/datasets/glider.rds")
