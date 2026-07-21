transform_metadata <- function (x) {
  x %>% 
    mutate(
      SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
    )
}

transform_detectiondata <- function (x) {
  x %>% 
    mutate(
      CALL_TYPE = case_when(
        SPECIES == "BLWH" ~ "BLMIX",
        SPECIES == "FIWH" ~ "FWMIX",
        SPECIES == "HUWH" ~ "HWMIX",
        TRUE ~ CALL_TYPE
      ),
      PROTOCOL_REFERENCE = case_when(
        str_starts(PROTOCOL_REFERENCE, "Kowarski et al. 2021; Delarue et al. 20") ~ "Kowarski et al. 2021; Delarue et al. 2022",
        TRUE ~ PROTOCOL_REFERENCE
      )
    ) %>% 
    rename(
      SPECIES_CODE = SPECIES,
      CALL_TYPE_CODE = CALL_TYPE
    )
}
