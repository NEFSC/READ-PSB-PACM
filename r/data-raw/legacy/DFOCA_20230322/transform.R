transform_metadata <- function (x) {
  x %>% 
    mutate(
      UNIQUE_ID = case_when(
        UNIQUE_ID == "GBK_2019_10" ~ "GBK_2019_10_HF",
        UNIQUE_ID == "SFD_2020_09" ~ "SFD_2020_09_HF",
        TRUE ~ UNIQUE_ID
      ),
      SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
    )
}

transform_detectiondata <- function (x) {
  x %>% 
    mutate(
      UNIQUE_ID = case_when(
        UNIQUE_ID == "WSS_2019_10" ~ "WSS_2019_HF",
        TRUE ~ UNIQUE_ID
      ),
      LOCALIZED_LATITUDE = NA_character_,
      LOCALIZED_LONGITUDE = NA_character_,
      DETECTION_DISTANCE_M = NA_character_,
      LOCALIZATION_DISTANCE_METHOD = NA_character_,
      LOCALIZATION_DISTANCE_PROTOCOL = NA_character_
    ) %>% 
    rename(CALL_TYPE_CODE = CALL_TYPE, SPECIES_CODE = SPECIES)
}
