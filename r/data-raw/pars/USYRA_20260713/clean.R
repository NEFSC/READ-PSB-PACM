library(tidyverse)

dir <- "data-raw/pars/USYRA_20260713"

metadata <- read_csv(file.path(dir, "raw/metadata.csv"), col_types = cols(.default = col_character()))
detectiondata <- read_csv(file.path(dir, "raw/detectiondata.csv"), col_types = cols(.default = col_character()))

metadata <- metadata |>
  mutate(
    recording_sample_rate_khz = as.character(as.numeric(recording_sample_rate_khz) / 1000)
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detectiondata, file.path(dir, "clean/detectiondata.csv"), na = "")
