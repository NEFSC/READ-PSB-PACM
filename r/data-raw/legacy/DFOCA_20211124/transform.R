
transform_metadata <- function (x) {
  x %>% 
    mutate(
      SUBMISSION_DATE = "2021-11-24"
    )
}

transform_detectiondata <- function (x) {
  x %>% 
    mutate(
      SPECIES = case_when(
        SPECIES == "HYAM" ~ "NBWH", # Northern Bottlenose
        SPECIES == "MEBI" ~ "SOBW", # Sowerby's
        SPECIES == "MMME" ~ "MEME", # Gervais'/True's
        SPECIES == "ZICA" ~ "GOBW", # Goose-beaked
        TRUE ~ SPECIES
      ),
      CALL_TYPE = case_when(
        SPECIES == "NBWH" & CALL_TYPE == "Frequency modulated upsweep" ~ "FMUS",
        SPECIES == "SOBW" & CALL_TYPE == "Frequency modulated upsweep" ~ "FMUS",
        SPECIES == "MEME" & CALL_TYPE == "Frequency modulated upsweep" ~ "FMUS",
        SPECIES == "GOBW" & CALL_TYPE == "Frequency modulated upsweep" ~ "FMUS",
        TRUE ~ CALL_TYPE
      ),
      LOCALIZED_LATITUDE = NA_character_,
      LOCALIZED_LONGITUDE = NA_character_,
      DETECTION_DISTANCE_M = NA_character_,
      LOCALIZATION_DISTANCE_METHOD = NA_character_,
      LOCALIZATION_DISTANCE_PROTOCOL = NA_character_
    ) %>% 
    rename(SPECIES_CODE = SPECIES, CALL_TYPE_CODE = CALL_TYPE)
}
