library(targets)
library(tarchetypes)
library(tidyverse)

# load all targets
tar_source(list.files("R", recursive = TRUE, pattern = ".R$", full.names = TRUE))

# packages
source("packages.R")

# load packages into session
if (interactive()) {
  sapply(tar_option_get("packages"), require, character.only = TRUE)
}

# load environment variables
if (file.exists(".env")) {
  dotenv::load_dot_env(file = ".env")
}

list(
  tar_target(data_dir, "./data-raw"),
  targets_gis,
  targets_ref,
  
  targets_towed_tracks,
  targets_towed_detections,
  targets_towed,

  targets_makara,
  targets_subs,
  
  targets_pacm
)
