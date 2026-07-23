library(targets)
library(tarchetypes)
library(tidyverse)

tar_source(list.files("R", recursive = TRUE, pattern = ".R$", full.names = TRUE))

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

  targets_makara,
  targets_pars_ref,
  targets_pars,

  targets_pacm,
  targets_export
)
