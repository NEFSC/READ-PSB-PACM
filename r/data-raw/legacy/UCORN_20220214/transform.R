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
      ),
      LOCALIZED_LATITUDE = NA_character_,
      LOCALIZED_LONGITUDE = NA_character_,
      DETECTION_DISTANCE_M = NA_character_,
      LOCALIZATION_DISTANCE_METHOD = NA_character_,
      LOCALIZATION_DISTANCE_PROTOCOL = NA_character_
    ) %>% 
    rename(CALL_TYPE_CODE = CALL_TYPE, SPECIES_CODE = SPECIES)
}
