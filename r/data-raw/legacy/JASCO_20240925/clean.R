library(tidyverse)

dir <- "data-raw/legacy/JASCO_20240925"

metadata <- read_csv(file.path(dir, "raw/JASCO_METADATA_20240925T114155Z_.csv"), col_types = cols(.default = col_character()))
detections <- read_csv(file.path(dir, "raw/JASCO_20240915_DETECTIONDATA.csv"), col_types = cols(.default = col_character()))

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
