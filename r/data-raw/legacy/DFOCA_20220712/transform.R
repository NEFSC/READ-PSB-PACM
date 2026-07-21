
transform_metadata <- function (x) {
  x %>% 
    mutate(
      SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
    )
}
