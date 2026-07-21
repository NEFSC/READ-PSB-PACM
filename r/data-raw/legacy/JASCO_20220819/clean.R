library(tidyverse)

dir <- "data-raw/legacy/JASCO_20220819"

metadata <- read_csv(file.path(dir, "raw/JASCO_METADATA_20220819.csv"), col_types = cols(.default = col_character())) |> 
  janitor::remove_empty("rows")
detections <- list.files(file.path(dir, "raw"), pattern = "DETECTIONDATA", full.names = TRUE) |>
  map_dfr(read_csv, col_types = cols(.default = col_character())) |> 
  janitor::remove_empty("rows")

metadata <- metadata |>
  mutate(
    SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
  )

detections <- detections |>
  mutate(
    CALL_TYPE = case_when(
      SPECIES == "BLWH" ~ "BLMIX",
      SPECIES == "FIWH" ~ "FWMIX",
      SPECIES == "HUWH" ~ "HWMIX",
      TRUE ~ CALL_TYPE
    ),
    PROTOCOL_REFERENCE = case_when(
      str_starts(PROTOCOL_REFERENCE, "Kowarski et al. 2021; Delarue et al. 20") ~ "Kowarski et al. 2021; Delarue et al. 2022",
      TRUE ~ PROTOCOL_REFERENCE
    )
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
