# JASCO_20260731

library(tidyverse)
library(janitor)
library(readxl)
library(glue)

dir <- "data-raw/pars/JASCO_20260731"

raw_metadata <- read_csv(
  file.path(dir, "raw", "metadata.csv"),
  col_types = cols(.default = col_character())
)
raw_detectiondata <- read_csv(
  file.path(dir, "raw", "detectiondata.csv"),
  col_types = cols(.default = col_character())
)
raw_gpsdata <- read_csv(
  file.path(dir, "raw", "gpsdata.csv"),
  col_types = cols(.default = col_character())
)

metadata <- raw_metadata
detectiondata <- raw_detectiondata |> 
  mutate(
    detection_result_code = case_match(
      detection_result_code,
      "D" ~ "DETECTED",
      .default = detection_result_code
    ),
    analysis_sound_source_codes = case_match(
      analysis_sound_source_codes,
      "ATCO,NARW,HUWH,FIWH,SEWH,MIWH,BLWH" ~ "ATCO,RIWH,HUWH,FIWH,SEWH,MIWH,BLWH",
      .default = analysis_sound_source_codes
    )
  )
tabyl(detectiondata, detection_result_code)
detectiondata |> 
  distinct(deployment_code, analysis_start_datetime, analysis_end_datetime)
tabyl(detectiondata, analysis_sound_source_codes)
gpsdata <- raw_gpsdata

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean", "metadata.csv"))
write_csv(detectiondata, file.path(dir, "clean", "detectiondata.csv"))
write_csv(gpsdata, file.path(dir, "clean", "gpsdata.csv"))

