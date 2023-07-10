#!/usr/bin/env Rscript
# Process PACM Dataset Submissions
# usage: C:\Users\jeffrey.walker\AppData\Local\Programs\R\R-4.2.3\bin\Rscript.exe .\cli\process-submissions.R -t <type> <submission id>
# example: C:\Users\jeffrey.walker\AppData\Local\Programs\R\R-4.2.3\bin\Rscript.exe .\cli\process-submissions.R -t external DFOCA_20211124

options(warn = -1, readr.show_progress = FALSE)
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(glue))
suppressPackageStartupMessages(library(janitor))
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(validate))
suppressPackageStartupMessages(library(logger))
suppressPackageStartupMessages(library(optparse))

dotenv::load_dot_env()
source("cli/functions.R")

log_appender(appender_stdout)

# arguments ---------------------------------------------------------------

parser <- OptionParser(
  usage = "usage: %prog [options] <SUBMISSION_ID> <SUBMISSION_ID> ...",
  description = "Process PACM dataset submissions for importing to database"
)
parser <- add_option(
  parser, c("-t", "--type"), type = "character",
  help = "Submission type (valid values: 'internal', 'external')"
)
# parser <- add_option(
#   parser, c("-r", "--retry"), type = "character",
#   help = "Retry submission from rejected directory"
# )
parser <- add_option(
  parser, c("-a", "--all"), action = "store_true", type = "logical", default = FALSE,
  help = "Flag to process all submissions located within raw directory"
)
parser <- add_option(
  parser, c("-d", "--dir"), type = "character", metavar = "/path/to/data", default = Sys.getenv("PACM_DATA_DIR"),
  help = "Path to root data directory (leave blank to load from env variable PACM_DATA_DIR)"
)
parser <- add_option(
  parser, c("--db-tables"), type = "character", metavar = "/path/to/db-tables.rds",
  help = "Path to db tables saved to rds file"
)
argv <- parse_args(parser, positional_arguments = TRUE)

log_info("PACM Dataset Submissions Processor")

data_dir <- argv$options$dir
log_info("directory: {data_dir}")
if (!dir.exists(data_dir)) {
  stop(glue("Data directory not found: {data_dir}"))
}
if (Sys.getenv("PACM_DATA_DIR") == "") {
  Sys.setenv("PACM_DATA_DIR" = data_dir)
}

type <- argv$options$type
log_info("type: {type}")
stopifnot(!is.null(type), type %in% c("internal", "external"))
if (!dir.exists(file.path(data_dir, type))) {
  stop(glue("Data directory for type '{type}' not found: {file.path(data_dir, type)}"))
}

if (argv$options$all) {
  ids <- list.dirs(file.path(data_dir, type, "raw"), full.names = FALSE, recursive = FALSE)
} else {
  ids <- argv$args
}
if (length(ids) == 0) {
  stop("No submission IDs found")
}
log_info("submission ids: {str_c(ids, collapse = ', ')}")

db_tables_arg <- argv$options$`db-tables`
db_tables <- NULL
if (!is.null(db_tables_arg)) {
  log_info("db tables: {argv$options$`db-tables`}")
  db_tables <- read_rds(argv$options$`db-tables`)
} else {
  db_tables <- load_db_tables()
}

# run ---------------------------------------------------------------------

walk(ids, function (id) {
  log_info(hr())
  process_submission(id, type = type, data_dir = data_dir, db_tables = db_tables)
})


# sandbox -----------------------------------------------------------------
#
# db_tables <- load_db_tables()
# write_rds(db_tables, "C:\\Users\\jeffrey.walker\\data\\pacm\\db-tables.rds")
# db_tables <- read_rds("C:\\Users\\jeffrey.walker\\data\\pacm\\db-tables.rds")
# db_tables$metadata <- head(db_tables$metadata, 0) # remove existing metadata
# codes <- load_codes(db_tables)

# type <- "external"
# id <- "JASCO_20230505"

# source("cli/functions.R")
# process_submission(id, type, db_tables = db_tables, write_log = FALSE)
# process_submission(id, type)
# x <- load_submission(id, type, db_tables = db_tables)
# qaqc_submission(x)
# export_submission(x)
# move_submission(x)
