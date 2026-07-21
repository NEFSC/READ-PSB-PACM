library(tidyverse)

dir <- "data-raw/legacy/_rejected/THMAH_20250815/"

raw_metadata <- read_csv(file.path(dir, "raw/THMAH_20250815_METADATA.csv"))
raw_detectiondata <- read_csv(file.path(dir, "raw/THMAH_20250815_DETECTIONDATA.csv"))

raw_metadata |> 
  tabyl(UNIQUE_ID)

metadata <- raw_metadata |>
  mutate(
    UNIQUE_ID = str_replace_all(UNIQUE_ID, " ", "")
  )

detectiondata <- raw_detectiondata |>
  mutate(
    UNIQUE_ID = str_replace_all(UNIQUE_ID, " ", "")
  )


dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detectiondata, file.path(dir, "clean/detectiondata.csv"), na = "")
