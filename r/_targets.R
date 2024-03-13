library(targets)

# packages
options(tidyverse.quiet = TRUE)
tar_option_set(packages = c(
  "tarchetypes",
  "tidyverse",
  "lubridate",
  "janitor",
  "glue",
  "units",
  "patchwork",
  "logger",
  "readxl",
  "validate",
  "sf",
  "dotenv",
  "validate"
))

# load packages into session
if (interactive()) {
  sapply(tar_option_get("packages"), require, character.only = TRUE)
}

# load all functions
source("cli/functions.R")
invisible(sapply(list.files("R", pattern = ".R", full.names = TRUE), source))
invisible(sapply(list.files("R/internal", pattern = ".R", full.names = TRUE), source))


list(
  tar_target(data_dir, Sys.getenv("PACM_DATA_DIR"), cue = tar_cue("always")),
  # targets_templates,
  # targets_refs,
  targets_gis,
  
  targets_db,
  
  targets_moored,
  targets_glider,
  targets_towed_tracks,
  targets_towed_detections,
  targets_towed,
  targets_nefsc_20230926,
  targets_nefsc_20230928,
  targets_davis_20230901,
  targets_davis_20231122,
  targets_internal,
  
  targets_external,
  targets_deployments,
  
  targets_pacm
  # targets_datasets,
)
