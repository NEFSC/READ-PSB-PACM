library(tidyverse)

dir <- "data-raw/submissions/DFOCA_20211124"

metadata <- read_csv(file.path(dir, "raw/DFOCA_METADATA_20211124.csv"), col_types = cols(.default = col_character()))
detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE) |>
  map_dfr(read_csv, col_types = cols(.default = col_character()))

detections <- detections |>
  mutate(
    SPECIES = case_when(
      SPECIES == "HYAM" ~ "NBWH",
      SPECIES == "MEBI" ~ "SOBW",
      SPECIES == "MMME" ~ "MMME",
      SPECIES == "ZICA" ~ "GOBW",
      TRUE ~ SPECIES
    ),
    CALL_TYPE = case_when(
      SPECIES == "NBWH" & CALL_TYPE == "Frequency modulated upsweep" ~ "OD_CLICK_FM",
      SPECIES == "SOBW" & CALL_TYPE == "Frequency modulated upsweep" ~ "OD_CLICK_FM",
      SPECIES == "MMME" & CALL_TYPE == "Frequency modulated upsweep" ~ "OD_CLICK_FM",
      SPECIES == "GOBW" & CALL_TYPE == "Frequency modulated upsweep" ~ "OD_CLICK_FM",
      TRUE ~ CALL_TYPE
    )
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
