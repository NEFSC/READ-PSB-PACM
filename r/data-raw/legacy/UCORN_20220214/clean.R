library(tidyverse)

dir <- "data-raw/legacy/UCORN_20220214"

metadata <- read_csv(file.path(dir, "raw/UCORN_METADATA_20220214.csv"), col_types = cols(.default = col_character()))
detections <- read_csv(file.path(dir, "raw/UCORN_DETECTIONDATA_20220217.csv"), col_types = cols(.default = col_character()))

metadata <- metadata |>
  mutate(
    SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
  )

detections <- detections |>
  mutate(
    SPECIES = case_when(
      SPECIES == "BAAC" ~ "MIWH",
      SPECIES == "BAPH" ~ "FIWH",
      SPECIES == "EUGL" ~ "RIWH",
      SPECIES == "MENO" ~ "HUWH",
      TRUE ~ SPECIES
    ),
    CALL_TYPE = case_when(
      SPECIES == "MIWH" & CALL_TYPE == "Pulse train" ~ "MWPT",
      SPECIES == "FIWH" & CALL_TYPE == "20Hz Pulse" ~ "FWPLS",
      SPECIES == "RIWH" & CALL_TYPE == "Upcall" ~ "UPCALL",
      SPECIES == "HUWH" & CALL_TYPE == "Song & Social" ~ "HWMIX",
    )
  )

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detectiondata.csv"), na = "")
