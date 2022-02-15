source("_targets.R")

# towed array -------------------------------------------------------------

tar_load(c(themes, refs))
metadata <- tar_read(nefsc_20220211_metadata)
detections <- tar_read(nefsc_20220211_detections)

species_groups <- themes %>% 
  rename(
    species_group = theme,
    species = species_code
  )

analyses <- species_groups %>% 
  inner_join(detections, by = "species") %>% 
  nest_by(
    species_group,
    unique_id,
    call_type,
    detection_method,
    qc_processing,
    protocol_reference,
    detection_software_name,
    detection_software_version,
    min_analysis_frequency_range_hz,
    max_analysis_frequency_range_hz,
    analysis_sampling_rate_hz,
    .key = "detections"
  ) %>% 
  ungroup() %>% 
  left_join(
    metadata %>% 
      select(unique_id, monitoring_start_datetime, monitoring_end_datetime, platform_type),
    by = "unique_id"
  )

# aggregate to daily
x_analysis <- analyses[1, ]
x_start_date <- as_date(x_analysis$monitoring_start_datetime)
x_end_date <- as_date(x_analysis$monitoring_end_datetime)
x_detections <- x_analysis$detections[[1]] %>% 
  mutate(date = as_date(analysis_period_start_datetime))
x_species_date <- x_detections %>% 
  nest_by(species, date, .key = "detections") %>% 
  ungroup() %>% 
  complete(date = seq.Date(x_start_date, x_end_date, by = "day"), species, fill = list(detections = list(tibble()))) %>% 
  rowwise() %>% 
  mutate(
    acoustic_presence = case_when(
      nrow(detections) == 0 ~ "N",
      sum(detections$acoustic_presence == "D") > 0 ~ "D",
      sum(detections$acoustic_presence == "P") > 0 ~ "P",
      TRUE ~ NA_character_
    )
  ) %>%
  print


# aggregate_detections() --------------------------------------------------

aggregate_detections <- function(detections, monitoring_start_datetime, monitoring_end_datetime, platform_type) {
  stopifnot(
    !is.na(monitoring_start_datetime),
    !is.na(monitoring_end_datetime),
    monitoring_end_datetime >= monitoring_start_datetime,
    !is.na(platform_type)
  )
  
  first_detection_date <- as_date(min(detections$analysis_period_start_datetime))
  last_detection_date <- as_date(max(detections$analysis_period_start_datetime))
  start_date <- min(first_detection_date, as_date(monitoring_start_datetime))
  end_date <- max(last_detection_date, as_date(monitoring_end_datetime))
  if (end_date > start_date & last_detection_date < as_date(monitoring_end_datetime) & end_date != as_date(monitoring_end_datetime - minutes(1))) {
    end_date <- end_date - days(1)
  }
  dates <- seq.Date(start_date, end_date, by = "day")
  
  x_date <- detections %>% 
    mutate(date = as_date(analysis_period_start_datetime))
  
  stopifnot(
    all(x_date$date >= start_date),
    all(x_date$date <= end_date)
  )
  
  x <- x_date %>% 
    nest_by(species, date, .key = "detections") %>% 
    ungroup() %>% 
    complete(date = dates, species, fill = list(detections = list(tibble()))) %>% 
    rowwise() 
  if (platform_type == "towed-array") {
    x <- x %>% 
      mutate(
        acoustic_presence = case_when(
          nrow(detections) == 0 ~ "N",
          sum(detections$acoustic_presence == "D") > 0 ~ "D",
          sum(detections$acoustic_presence == "P") > 0 ~ "P",
          sum(detections$acoustic_presence == "M") > 0 ~ "M",
          TRUE ~ NA_character_
        )
      )
  } else {
    x <- x %>% 
      mutate(
        acoustic_presence = case_when(
          nrow(detections) == 0 ~ "M",
          sum(detections$acoustic_presence == "D") > 0 ~ "D",
          sum(detections$acoustic_presence == "P") > 0 ~ "P",
          sum(detections$acoustic_presence == "N") > 0 ~ "N",
          sum(detections$acoustic_presence == "M") > 0 ~ "M",
          TRUE ~ NA_character_
        )
      )
  }
  ungroup(x)
}

df_daily <- analyses %>% 
  mutate(
    detections = pmap(list(detections, monitoring_start_datetime, monitoring_end_datetime, platform_type), aggregate_detections)
  ) %>% 
  select(-c(monitoring_start_datetime, monitoring_end_datetime, platform_type))



# dfo -------------------------------------------------------------------

metadata <- tar_read(dfo_20211124_metadata)
detections <- tar_read(dfo_20211124_detections)

create_analyses <- function (metadata, detections, refs) {
  refs[["species_group"]] %>% 
    inner_join(detections, by = "species") %>% 
    nest_by(
      species_group,
      unique_id,
      call_type,
      detection_method,
      qc_processing,
      protocol_reference,
      detection_software_name,
      detection_software_version,
      min_analysis_frequency_range_hz,
      max_analysis_frequency_range_hz,
      analysis_sampling_rate_hz,
      .key = "detections"
    ) %>% 
    ungroup() %>% 
    left_join(
      metadata %>% 
        select(unique_id, monitoring_start_datetime, monitoring_end_datetime, platform_type),
      by = "unique_id"
    ) %>% 
    mutate(
      detections = pmap(list(detections, monitoring_start_datetime, monitoring_end_datetime, platform_type), aggregate_detections)
    ) %>% 
    select(-c(monitoring_start_datetime, monitoring_end_datetime, platform_type))
}

dfo_20211124_analyses <- create_analyses(tar_read(dfo_20211124_metadata), tar_read(dfo_20211124_detections), species_groups)

dfo_20211124_analyses %>% 
  select(species_group, unique_id, detections) %>%
  unnest(detections) %>% 
  tabyl(species, acoustic_presence, species_group) %>% 
  adorn_totals(where = "both")

dfo_20211124_analyses %>% 
  select(species_group, unique_id, detections) %>%
  unnest(detections) %>% 
  ggplot(aes(date, species)) +
  geom_point(aes(color = acoustic_presence)) +
  facet_wrap(vars(unique_id), scales = "free_x")

nydec_20211216_analyses <- create_analyses(tar_read(nydec_20211216_metadata), tar_read(nydec_20211216_detections), species_groups)

nydec_20211216_analyses %>% 
  select(species_group, unique_id, detections) %>%
  unnest(detections) %>% 
  tabyl(species, acoustic_presence, species_group) %>% 
  adorn_totals(where = "both")

nydec_20211216_analyses %>% 
  select(species_group, unique_id, detections) %>%
  unnest(detections) %>% 
  ggplot(aes(date, acoustic_presence)) +
  geom_point(aes(color = acoustic_presence)) +
  facet_wrap(vars(unique_id), scales = "free_x")

nefsc_20220211_analyses <- create_analyses(tar_read(nefsc_20220211_metadata), tar_read(nefsc_20220211_detections), species_groups)

nefsc_20220211_analyses %>% 
  select(species_group, unique_id, detections) %>%
  unnest(detections) %>%
  tabyl(species, acoustic_presence, species_group) %>% 
  adorn_totals(where = "both")

nefsc_20220211_analyses %>% 
  select(species_group, unique_id, detections) %>%
  unnest(detections) %>% 
  ggplot(aes(date, acoustic_presence)) +
  geom_point(aes(color = acoustic_presence)) +
  facet_wrap(vars(unique_id), scales = "free_x")

nefsc_20211216_analyses <- create_analyses(tar_read(nefsc_20211216_metadata), tar_read(nefsc_20211216_detections), species_groups)

nefsc_20211216_analyses %>% 
  select(species_group, unique_id, detections) %>%
  unnest(detections) %>%
  tabyl(species, acoustic_presence, species_group) %>% 
  adorn_totals(where = "both")

nefsc_20211216_analyses %>% 
  select(species_group, unique_id, detections) %>%
  unnest(detections) %>% 
  ggplot(aes(date, acoustic_presence)) +
  geom_point(aes(color = acoustic_presence)) +
  facet_wrap(vars(unique_id), scales = "free_x")



# process_dataset() -------------------------------------------------------

process_dataset <- function(files, clean = NULL, refs) {
  if (is.null(clean)) {
    clean <- list(
      metadata = function (x) {x},
      detections = function (x) {x}
    )
  } else if (!"metadata" %in% names(clean)) {
    clean[["metadata"]] <- function (x) {x}
  } else if (!"detections" %in% names(clean)) {
    clean[["detections"]] <- function (x) {x}
  }
  
  metadata_raw <- read_csv(files[["metadata"]], col_types = cols(.default = col_character()), na = "NA")
  metadata_clean <- clean[["metadata"]](metadata_raw)
  metadata_valid <- validate_metadata(metadata_clean)
  stopifnot(nrow(metadata_valid$rejected) == 0)
  metadata <- metadata_valid$data
  
  detections_raw <- read_csv(files[["detections"]], col_types = cols(.default = col_character()), na = "NA")
  detections_clean <- clean[["detections"]](detections_raw)
  detections_valid <-  validate_detections(detections_clean, metadata, refs)
  stopifnot(nrow(detections_valid$rejected) == 0)
  detections <- detections_valid$data
  
  analyses <- create_analyses(metadata, detections, refs)
  
  list(
    recorders = metadata,
    detections = detections,
    analyses = analyses
  )
}

tar_load(refs)
nefsc_20220211 <- process_dataset(
  list(
    metadata = "data/nefsc/20220211-hb1603/NEFSC_METADATA_20220211.csv",
    detections = "data/nefsc/20220211-hb1603/NEFSC_DETECTIONS_20220211.csv"
  ),
  list(
    metadata = function (x) {
      x %>% 
        mutate(
          SUBMISSION_DATE = "2022-02-11T00:00:00-0500"
        )
    },
    detections = function (x) {
      x %>% 
        mutate(
          CALL_TYPE = NA_character_
        )
    }
  ),
  refs
)
