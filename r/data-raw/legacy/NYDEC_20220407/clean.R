library(tidyverse)

dir <- "data-raw/submissions/NYDEC_20220407"

metadata <- read_csv(file.path(dir, "raw/NYDEC_METADATA_20220407.csv"), col_types = cols(.default = col_character()))
detections <- read_csv(file.path(dir, "raw/NYDEC_DETECTIONDATA_20220321.csv"), col_types = cols(.default = col_character()))

metadata <- metadata |>
  mutate(
    SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
  )

detections <- detections |>
  mutate(
    SPECIES = case_when(
      SPECIES == "EUGL" ~ "RIWH",
      TRUE ~ SPECIES
    ),
    CALL_TYPE = case_when(
      SPECIES == "RIWH" & CALL_TYPE == "Upcall" ~ "UPCALL",
      TRUE ~ CALL_TYPE
    ),
    ANALYSIS_SAMPLING_RATE_HZ = coalesce(ANALYSIS_SAMPLING_RATE_HZ, "2000"),
    LOCALIZED_LATITUDE = NA_character_,
    LOCALIZED_LONGITUDE = NA_character_,
    DETECTION_DISTANCE_M = NA_character_,
    LOCALIZATION_DISTANCE_METHOD = NA_character_,
    LOCALIZATION_DISTANCE_PROTOCOL = NA_character_
  ) |>
  rename(CALL_TYPE_CODE = CALL_TYPE, SPECIES_CODE = SPECIES)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
