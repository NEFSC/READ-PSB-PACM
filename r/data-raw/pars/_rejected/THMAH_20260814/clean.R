library(tidyverse)

dir <- "data-raw/pars/THMAH_20260814"

metadata <- read_csv(file.path(dir, "raw/metadata.csv"), col_types = cols(.default = col_character()), na = c("N/A", "NA", "")) |> 
  mutate(
    across(everything(), ~iconv(., from = "UTF-8", to = "UTF-8", sub = "")),
    across(ends_with("depth_m"), ~ -1 * as.numeric(.)),
    # across(c(monitoring_start_datetime, monitoring_end_datetime), ~ paste0(., "Z")),
  )
detectiondata <- read_csv(file.path(dir, "raw/detectiondata.csv"), col_types = cols(.default = col_character()), na = c("N/A", "NA", "")) |> 
  mutate(
    across(everything(), ~iconv(., from = "UTF-8", to = "UTF-8", sub = "")),
    across(ends_with("datetime"), ~ paste0(., "Z")),
    across(c("detection_effort_secs", "localization_distance_m"), ~ str_remove_all(., ","))
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detectiondata, file.path(dir, "clean/detectiondata.csv"), na = "")
