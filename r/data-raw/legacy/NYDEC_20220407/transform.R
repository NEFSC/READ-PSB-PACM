transform_metadata <- function (x) {
  x %>% 
    mutate(
      SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
    )
}

transform_detectiondata <- function (x) {
  x %>% 
    mutate(
      SPECIES = case_when(
        SPECIES == "EUGL" ~ "RIWH",
        TRUE ~ SPECIES
      ),
      CALL_TYPE = case_when(
        SPECIES == "RIWH" & CALL_TYPE == "Upcall" ~ "UPCALL",
        TRUE ~ CALL_TYPE
      ),
      ANALYSIS_SAMPLING_RATE_HZ = coalesce(ANALYSIS_SAMPLING_RATE_HZ, "2000"),
      LOCALIZED_LATITUDE = NA_character_,
      LOCALIZED_LONGITUDE = NA_character_,
      DETECTION_DISTANCE_M = NA_character_,
      LOCALIZATION_DISTANCE_METHOD = NA_character_,
      LOCALIZATION_DISTANCE_PROTOCOL = NA_character_
    ) %>% 
    rename(CALL_TYPE_CODE = CALL_TYPE, SPECIES_CODE = SPECIES)
}
