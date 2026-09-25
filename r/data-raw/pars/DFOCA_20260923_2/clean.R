library(tidyverse)

dir <- "data-raw/pars/DFOCA_20260923_2"

metadata <- read_csv(file.path(dir, "raw/metadata.csv"), col_types = cols(.default = col_character()), na = c("N/A", "NA", "")) |> 
  mutate(
    across(everything(), ~iconv(., from = "UTF-8", to = "UTF-8", sub = "")),
  )
detectiondata <- read_csv(file.path(dir, "raw/detectiondata.csv"), col_types = cols(.default = col_character()), na = c("N/A", "NA", "")) |> 
  mutate(
    across(everything(), ~iconv(., from = "UTF-8", to = "UTF-8", sub = "")),
    analysis_detector_code = case_when(
      deployment_code == "EMBD-2016-09-8" & analysis_sound_source_codes == "BLWH" & analysis_detector_code == "JASCO_AA, LFDCS" ~ "LFDCS",
      TRUE ~ analysis_detector_code
    )
  )

tabyl(detectiondata, analysis_sound_source_codes, analysis_detector_code)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detectiondata, file.path(dir, "clean/detectiondata.csv"), na = "")
