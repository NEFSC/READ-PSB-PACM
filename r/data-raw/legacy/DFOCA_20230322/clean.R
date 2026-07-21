library(tidyverse)

dir <- "data-raw/submissions/DFOCA_20230322"

metadata <- read_csv(file.path(dir, "raw/DFOCA_METADATA_20230323.csv"), col_types = cols(.default = col_character()))
detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE) |>
  map_dfr(read_csv, col_types = cols(.default = col_character()))

metadata <- metadata |>
  mutate(
    UNIQUE_ID = case_when(
      UNIQUE_ID == "GBK_2019_10" ~ "GBK_2019_10_HF",
      UNIQUE_ID == "SFD_2020_09" ~ "SFD_2020_09_HF",
      TRUE ~ UNIQUE_ID
    )
  )

detections <- detections |>
  mutate(
    UNIQUE_ID = case_when(
      UNIQUE_ID == "WSS_2019_10" ~ "WSS_2019_HF",
      TRUE ~ UNIQUE_ID
    )
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
