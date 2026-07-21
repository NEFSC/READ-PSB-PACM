library(tidyverse)
library(janitor)

dir <- "data-raw/submissions/UCORN_20230822"

metadata_2019 <- read_csv(file.path(dir, "..", "UCORN_20190205", "clean", "metadata.csv"), col_types = cols(.default = col_character()))
detections_2019 <- read_csv(file.path(dir, "..", "UCORN_20190205", "clean", "detectiondata.csv"), col_types = cols(.default = col_character()))

detections_2019_meta <- detections_2019 |> 
  distinct(ANALYSIS_PERIOD_EFFORT_SECONDS, DETECTION_METHOD, PROTOCOL_REFERENCE, SPECIES_CODE, CALL_TYPE_CODE, QC_PROCESSING)

raw_detections <- read_csv(
  file.path(dir, "raw", "YangCenter_AutoBuoy_Data_2019-2023.csv"),
  col_types = cols(.default = col_character())
)

detections <- raw_detections |> 
  pivot_longer(-DATE, names_to = "UNIQUE_ID", values_to = "N_DETECTIONS") |>
  mutate(N_DETECTIONS = as.integer(N_DETECTIONS)) |> 
  transmute(
    UNIQUE_ID = paste0("CORNELL_TSS_AUTOBUOYS_", as.integer(str_replace(UNIQUE_ID, "AB", ""))),
    ANALYSIS_PERIOD_START_DATETIME = paste0(DATE, "T00:00:00"),
    ANALYSIS_PERIOD_END_DATETIME = paste0(DATE, "T23:59:59"),
    ACOUSTIC_PRESENCE = case_when(
      N_DETECTIONS == 0 ~ "n",
      N_DETECTIONS > 0 ~ "y",
      TRUE ~ NA_character_
    )
  ) |> 
  bind_cols(detections_2019_meta)

tabyl(detections, UNIQUE_ID, DETECTION_METHOD)
tabyl(detections, SPECIES_CODE, CALL_TYPE_CODE)

stopifnot(
  all(detections$UNIQUE_ID %in% metadata_2019$UNIQUE_ID)
)

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
