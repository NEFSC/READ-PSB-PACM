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

  # the towed array is now the TOWED_LEGACY PARS submission (T2.5, AD-11);
  # R/towed/ and its targets_towed_* lists are removed
  targets_makara,
  targets_pars_ref,
  targets_pars,
  targets_legacy,

  targets_pacm
)
