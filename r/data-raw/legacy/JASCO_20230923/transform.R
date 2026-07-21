transform_metadata <- function (x) {
  x %>% 
    mutate(
      UNIQUE_ID = paste(UNIQUE_ID, "20230923", sep = "_"),
      SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
    )
}

transform_detectiondata <- function (x) {
  x %>% 
    mutate(
      UNIQUE_ID = paste(UNIQUE_ID, "20230923", sep = "_"),
      ANALYSIS_TIME_ZONE = "UTC"
    )
}
