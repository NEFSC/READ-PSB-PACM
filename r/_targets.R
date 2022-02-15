library(targets)

# packages
options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "lubridate", "janitor", "glue", "units", "patchwork", "logger", "readxl", "validate", "sf"))

# load packages into session
if (interactive()) {
  sapply(tar_option_get("packages"), require, character.only = TRUE)
}

# load all functions
invisible(sapply(list.files("R", pattern = ".R", full.names = TRUE), source))
invisible(sapply(list.files("R/datasets", pattern = ".R", full.names = TRUE), source))

list(
  targets_template,
  
  targets_datasets
  
  # targets_dfo_20211124,   # beaked
  # targets_nydec_20211216, # baleen
  # targets_nefsc_20211216, # harbor porpoise
  # targets_nefsc_20220211  # hb1603
)
