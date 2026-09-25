library(tidyverse)

dir <- "data-raw/pars/DFOCA_20260925_5"

detectiondata <- read_csv(file.path(dir, "raw/detectiondata.csv"), col_types = cols(.default = col_character()), na = c("N/A", "NA", "")) |> 
  mutate(
    across(everything(), ~iconv(., from = "UTF-8", to = "UTF-8", sub = "")),
  )

tabyl(detectiondata, analysis_sound_source_codes, analysis_detector_code)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(detectiondata, file.path(dir, "clean/detectiondata.csv"), na = "")
