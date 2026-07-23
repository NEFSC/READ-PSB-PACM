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

  # the towed array is now the TOWED_LEGACY PARS submission, and every legacy
  # submission has been converted to a PARS submission under data-raw/pars/,
  # so R/towed/, R/legacy.R and their target lists are removed - all
  # non-Makara data now flows through targets_pars
  targets_makara,
  targets_pars_ref,
  targets_pars,

  targets_pacm,
  targets_export
)
