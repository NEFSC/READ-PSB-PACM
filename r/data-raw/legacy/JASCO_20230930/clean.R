library(tidyverse)

dir <- "data-raw/submissions/JASCO_20230930"

metadata <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "METADATA", full.names = TRUE),
  col_types = cols(.default = col_character())
) |> 
  janitor::remove_empty("rows")
detections <- read_csv(
  list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE),
  col_types = cols(.default = col_character())
) |> 
  janitor::remove_empty("rows")

metadata <- metadata |>
  mutate(
    UNIQUE_ID = paste(UNIQUE_ID, "20230930", sep = "_"),
    LONGITUDE = as.character(-1 * abs(parse_number(LONGITUDE)))
  )

detections <- detections |>
  mutate(
    UNIQUE_ID = paste(UNIQUE_ID, "20230930", sep = "_"),
    ANALYSIS_TIME_ZONE = "UTC"
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
