transform_metadata <- function (x) {
  x %>% 
    mutate(
      UNIQUE_ID = paste0(UNIQUE_ID, "_", str_remove_all(str_sub(MONITORING_START_DATETIME, 1, 10), "-")),
      SUBMITTER_NAME = "Colin Macomber",
      SUBMITTER_AFFILIATION = "ORSTED",
      SUBMITTER_EMAIL = "comac@orsted.com",
      SUBMISSION_DATE = "2024-04-18"
    )
}

transform_detectiondata <- function (x) {
  x %>%
    mutate(
      DATE = str_remove_all(str_sub(ANALYSIS_PERIOD_START_DATETIME, 1, 10), "-"),
      DATE = case_when(
        DATE == "20230722" ~ "20230721",
        DATE == "20230724" ~ "20230723",
        DATE == "20230806" ~ "20230805",
        TRUE ~ DATE
      ),
      UNIQUE_ID = paste0(UNIQUE_ID, "_", DATE)
    ) %>% 
    select(-DATE) %>% 
    filter(
      !is.na(UNIQUE_ID),
      UNIQUE_ID != "NA_NA",
      !SPECIES_CODE %in% c("UNMY")
    )
}
