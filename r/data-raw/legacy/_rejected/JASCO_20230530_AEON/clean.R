library(tidyverse)
library(janitor)

dir <- "data-raw/submissions/JASCO_20230530_AEON"

raw_metadata <- read_csv(
  file.path(dir, "raw", c("MetadataAEON.csv")),
  col_types = cols(.default = col_character())
)
raw_detections <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE),
  id = "$file",
  col_types = cols(.default = col_character())
) |> 
  filter(!basename(`$file`) == "JASCO_DETECTIONDATA_20230517T160313Z_AEON1bLF.csv")
tabyl(raw_detections, `$file`)

raw_detections_updated <- read_csv(
  list.files(file.path(dir, "updated"), pattern = "DETECTIONDATA", full.names = TRUE),
  id = "$file",
  col_types = cols(.default = col_character())
) |> 
  rename(SPECIES = SPECIES_CODE, CALL_TYPE = CALL_TYPE_CODE)

raw_detections <- bind_rows(raw_detections, raw_detections_updated)

metadata <- raw_metadata |> 
  mutate(
    # UNIQUE_ID = case_when(
    #   str_detect(`$file`, "_HF_") ~ glue("{UNIQUE_ID}-HF"),
    #   str_detect(`$file`, "_LF_") ~ glue("{UNIQUE_ID}-LF"),
    #   TRUE ~ UNIQUE_ID
    # ),
    # UNIQUE_ID = str_replace(UNIQUE_ID, " ", ""),
    UNIQUE_ID2 = map_chr(UNIQUE_ID, ~ str_split(.x, "\\.")[[1]][1]),
    PLATFORM_TYPE = case_when(
      PLATFORM_TYPE == "Bottom-mounted" ~ "BOTTOM_MOUNTED_MOORING",
      TRUE ~ PLATFORM_TYPE
    )
  )
metadata |> 
  add_count(UNIQUE_ID2) |> 
  filter(n > 1) |> 
  distinct(UNIQUE_ID, UNIQUE_ID2)
tabyl(metadata, UNIQUE_ID)
stopifnot(!anyDuplicated(metadata$UNIQUE_ID))

# ERROR: unable to resolve differences in UNIQUE_ID between metadata and detections
setdiff(unique(raw_detections$UNIQUE_ID), metadata$UNIQUE_ID)
tabyl(raw_detections, UNIQUE_ID, SPECIES)
analyses <- raw_detections |> 
  janitor::remove_empty("cols") |> 
  mutate(
    UNIQUE_ID = case_when(
      str_detect(`$file`, "_HF_") ~ glue("{UNIQUE_ID}-HF"),
      str_detect(`$file`, "_LF_") ~ glue("{UNIQUE_ID}-LF"),
      TRUE ~ UNIQUE_ID
    ),
    UNIQUE_ID = str_replace(UNIQUE_ID, " ", "")
  ) |> 
  rename(SPECIES_CODE = SPECIES, CALL_TYPE_CODE = CALL_TYPE) |>
  select(-`$file`) |> 
  nest(detections = c(
    ANALYSIS_PERIOD_START_DATETIME, ANALYSIS_PERIOD_END_DATETIME, ANALYSIS_PERIOD_EFFORT_SECONDS,
    ACOUSTIC_PRESENCE, N_VALIDATED_DETECTIONS, CALL_TYPE_CODE, DETECTION_COMMENTS
  ))

stopifnot(
  analyses |> 
    count(UNIQUE_ID, SPECIES_CODE) |>
    filter(n > 1) |> 
    nrow() == 0,
  all(analyses$UNIQUE_ID %in% metadata$UNIQUE_ID)
)

detections <- analyses |> 
  mutate(
    detections = map(detections, function (x) {
      x |> 
        mutate(
          across(
            c(ANALYSIS_PERIOD_START_DATETIME, ANALYSIS_PERIOD_END_DATETIME),
            ymd_hms
          ),
          DATE = as_date(ANALYSIS_PERIOD_START_DATETIME)
        ) |>
        group_by(DATE) |> 
        summarise(
          ANALYSIS_PERIOD_START_DATETIME = min(ANALYSIS_PERIOD_START_DATETIME),
          ANALYSIS_PERIOD_END_DATETIME = max(ANALYSIS_PERIOD_END_DATETIME),
          ANALYSIS_PERIOD_EFFORT_SECONDS = sum(as.numeric(ANALYSIS_PERIOD_EFFORT_SECONDS)),
          ACOUSTIC_PRESENCE = case_when(
            any(ACOUSTIC_PRESENCE == "D") ~ "D",
            any(ACOUSTIC_PRESENCE == "N") ~ "N",
            TRUE ~ NA_character_
          ),
          N_VALIDATED_DETECTIONS = sum(as.integer(N_VALIDATED_DETECTIONS)),
          CALL_TYPE_CODE = paste(unique(na.omit(CALL_TYPE_CODE)), collapse = ","),
          DETECTION_COMMENTS = paste(unique(na.omit(DETECTION_COMMENTS)), collapse = ";"),
          .groups = "drop"
        )
    })
  ) |> 
  unnest(detections) |> 
  select(-DATE)
detections

# dir.create(file.path(dir, "clean"), showWarnings = FALSE)
# write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
# write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
