#!/usr/bin/env Rscript
# re-run the clean.R script for every PARS submission in the manifest
# note: pars_sub_* targets are not rebuilt automatically (cue = "never"),
# so run make_pars() afterwards to reload the cleaned submissions

source("_targets.R")
invisible(sapply(tar_option_get("packages"), require, character.only = TRUE))

for (id in pars_manifest$submission_id) {
  message("cleaning: ", id)
  clean_pars(id)
}
