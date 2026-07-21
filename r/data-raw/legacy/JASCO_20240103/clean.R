library(tidyverse)

dir <- "data-raw/submissions/JASCO_20240103"

metadata <- read_csv(file.path(dir, "raw/JASCO_20240103_METADATA.csv"), col_types = cols(.default = col_character())) |> 
  janitor::remove_empty("rows")
detections <- read_csv(file.path(dir, "raw/JASCO_20240103_DETECTIONDATA.csv"), col_types = cols(.default = col_character())) |> 
  janitor::remove_empty("rows")

metadata <- metadata |>
  mutate(
    UNIQUE_ID = paste(UNIQUE_ID, "20240103", sep = "_"),
    LONGITUDE = paste0("-", LONGITUDE)
  )

detections <- detections |>
  mutate(
    UNIQUE_ID = paste(UNIQUE_ID, "20240103", sep = "_"),
    ANALYSIS_TIME_ZONE = "UTC"
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
