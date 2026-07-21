transform_metadata <- function (x) {
  x %>% 
    mutate(
      SUBMISSION_DATE = "2024-09-25"
    )
}

transform_detectiondata <- function (x) {
  x %>%
    mutate(
      ACOUSTIC_PRESENCE = case_when(
        toupper(ACOUSTIC_PRESENCE) == "Y" ~ "D",
        toupper(ACOUSTIC_PRESENCE) == "N" ~ "N",
        TRUE ~ ACOUSTIC_PRESENCE
      )
    )
}
