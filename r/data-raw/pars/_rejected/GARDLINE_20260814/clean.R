library(tidyverse)

dir <- "data-raw/pars/GARDLINE_20260814"

metadata <- read_csv(file.path(dir, "raw/metadata.csv"), col_types = cols(.default = col_character()), na = c("N/A", "NA", "")) |> 
  janitor::remove_empty() |> 
  mutate(
    # across(c(monitoring_start_datetime, monitoring_end_datetime), ~ paste0(., "Z")),
  )
detectiondata <- read_csv(file.path(dir, "raw/detectiondata.csv"), col_types = cols(.default = col_character()), na = c("N/A", "NA", "")) |> 
  filter(!is.na(deployment_code)) |> 
  mutate(
    # across(ends_with("datetime"), ~ paste0(., "Z")),
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detectiondata, file.path(dir, "clean/detectiondata.csv"), na = "")
