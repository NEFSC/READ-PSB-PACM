library(targets)

# packages
options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "lubridate", "janitor", "glue", "units", "patchwork", "logger", "readxl", "validate"))

# load packages into session
if (interactive()) {
  sapply(tar_option_get("packages"), require, character.only = TRUE)
}

# load all functions
invisible(sapply(list.files("R", pattern = ".R", full.names = TRUE), source))

# load all targets
invisible(sapply(list.files("targets", full.names = TRUE), source))

list(
  tar_target(ref_call_type, {
    c(
      "Upcall",
      "Moan",
      "Gunshot",
      "20Hz Pulse",
      "Song",
      "Social",
      "Song & Social",
      "A/B/AB song",
      "Arch",
      "Frequency modulated upsweep",
      "Narrow band high frequency click",
      "Pulse train"
    )
  }),
  tar_target(ref_qc_processing, {
    c(
      "Real-time",
      "Archival"
    )
  }),
  tar_target(ref_species, {
    read_excel(template_detections_file, sheet = "Species_Codes") %>% 
      clean_names()
  }),
  tar_target(refs, {
    list(
      call_type = ref_call_type,
      qc_processing = ref_qc_processing,
      species = ref_species,
      acoustic_presences = c("D", "P", "N", "M")
    )
  }),
  tar_target(template_metadata_file, "data/templates/PACM_TEMPLATE_METADATA.xlsx", format = "file"),
  tar_target(template_detections_file, "data/templates/PACM_TEMPLATE_DETECTIONDATA.xlsx", format = "file"),
  tar_target(template_gps_file, "data/templates/PACM_TEMPLATE_GPSDATA.xlsx", format = "file"),
  
  # nydec-20211216
  tar_target(nydec_metadata_file, "data/nydec/20211216-baleen/NYDEC_METADATA_20211216.xlsx", format = "file"),
  tar_target(nydec_metadata_raw, read_excel(nydec_metadata_file, sheet = 1, col_types = "text")),
  tar_target(nydec_metadata_fixed, {
    nydec_metadata_raw %>%
      mutate(
        across(
          c(
            MONITORING_START_DATETIME,
            MONITORING_END_DATETIME
          ),
          ~ format(ymd(19000101) + days(parse_number(.x) - 2), "%FT%T%z")
        ),
        SUBMISSION_DATE = ymd_hms(str_replace(SUBMISSION_DATE, "T0", "T"))
      )
  }),
  tar_target(nydec_metadata, validate_metadata(nydec_metadata_fixed)),
  tar_target(nydec_detections_file, "data/nydec/20211216-baleen/NYDEC_DETECTIONDATA_20211216.xlsx", format = "file"),
  tar_target(nydec_detections_raw, read_excel(nydec_detections_file, sheet = 1, col_types = "text")),
  tar_target(nydec_detections_fixed, { nydec_detections_raw }),
  tar_target(nydec_detections, validate_detections(nydec_detections_fixed, unique(nydec_metadata$data$unique_id), refs)),
  
  # nefsc-20211216 (harbor-porpoise)
  tar_target(nefsc_20211216_metadata_file, "data/nefsc/20211216-harbor-porpoise/NEFSC_METADATA_20211216.csv", format = "file"),
  tar_target(nefsc_20211216_metadata_raw, read_csv(nefsc_20211216_metadata_file, col_types = cols(.default = col_character()))),
  tar_target(nefsc_20211216_metadata_fixed, { nefsc_20211216_metadata_raw }),
  tar_target(nefsc_20211216_metadata, validate_metadata(nefsc_20211216_metadata_fixed)),
  tar_target(nefsc_20211216_detections_file, "data/nefsc/20211216-harbor-porpoise/NEFSC_DETECTIONDATA_20211216.csv", format = "file"),
  tar_target(nefsc_20211216_detections_raw, read_csv(nefsc_20211216_detections_file, col_types = cols(.default = col_character()))),
  tar_target(nefsc_20211216_detections_fixed, {
    nefsc_20211216_detections_raw %>% 
      mutate(
        CALL_TYPE = case_when(
          CALL_TYPE == "NBHF Clicks" ~ "Narrow band high frequency click",
          TRUE ~ CALL_TYPE
        )
      )
  }),
  tar_target(nefsc_20211216_detections, validate_detections(nefsc_20211216_detections_fixed, unique(nefsc_20211216_metadata$data$unique_id), refs))
)
