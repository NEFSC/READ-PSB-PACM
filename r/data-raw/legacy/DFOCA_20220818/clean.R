library(tidyverse)

dir <- "data-raw/submissions/DFOCA_20220818"

detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE) |>
  map_dfr(read_csv, col_types = cols(.default = col_character()))

detections <- detections |>
  mutate(
    CALL_TYPE = case_when(
      CALL_TYPE == "Full Frequency Downsweep (singlet, doublet, triplet)" & SPECIES == "SEWH" ~ "SWDS",
      TRUE ~ CALL_TYPE
    )
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
