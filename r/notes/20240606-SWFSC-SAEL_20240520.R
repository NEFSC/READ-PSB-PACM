# SWFSC-SAEL_20240520

source("_targets.R")

external_dir <- "data/external"
db_tables <- read_rds(file.path(external_dir, "db-tables.rds"))
x <- load_external_submission(
  id = "SWFSC-SAEL_20240520", 
  root_dir = external_dir, 
  db_tables = db_tables
)

x$metadata %>% 
  filter(n_errors > 0) %>% 
  pull(filename)


# duplicate UNIQUE_IDs (different recorders):
# - SWFSC_NEPac-MBY_201608_Pascal_009
# - SWFSC_NEPac-SND_201609_Pascal_024
# - SWFSC_NEPac-CHI_201609_Pascal_026
# - SWFSC_NEPac-CHI_201609_Pascal_030

