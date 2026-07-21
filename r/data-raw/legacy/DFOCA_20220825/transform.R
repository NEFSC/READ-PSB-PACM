
transform_detectiondata <- function (x) {
  x %>% 
    mutate(
      CALL_TYPE = case_when(
        CALL_TYPE == "Full Frequency Downsweeps (Singlet, Doublet, Triplet)" & SPECIES == "SEWH" ~ "SWDS",
        TRUE ~ CALL_TYPE
      ),
      LOCALIZED_LATITUDE = NA_character_,
      LOCALIZED_LONGITUDE = NA_character_,
      DETECTION_DISTANCE_M = NA_character_,
      LOCALIZATION_DISTANCE_METHOD = NA_character_,
      LOCALIZATION_DISTANCE_PROTOCOL = NA_character_
    ) %>% 
    rename(CALL_TYPE_CODE = CALL_TYPE, SPECIES_CODE = SPECIES)
}
