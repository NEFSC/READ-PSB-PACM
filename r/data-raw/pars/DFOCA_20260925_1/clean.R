library(tidyverse)

dir <- "data-raw/pars/DFOCA_20260925_1"

metadata <- read_csv(file.path(dir, "raw/metadata.csv"), col_types = cols(.default = col_character()), na = c("N/A", "NA", "")) |> 
  mutate(
    across(everything(), ~iconv(., from = "UTF-8", to = "UTF-8", sub = "")),
  )
# detectiondata: replaced by DFOCA_20260925_4

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
