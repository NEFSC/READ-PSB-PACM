# SWFSC-SAEL_20240814 (replaces SWFSC-SAEL_20240617)

source("_targets.R")

external_dir <- "data/external"
db_tables <- read_rds(file.path(external_dir, "db-tables.rds"))
db_tables$species <- db_tables$species %>% 
  bind_rows(
    tibble(SPECIES_CODE = c("BWBB", "BWMS", "BWMC", "BW43", "BWC", "NBHF"))
  )

x <- load_external_submission(
  id = "SWFSC-SAEL_20240814", 
  root_dir = external_dir, 
  db_tables = db_tables
)

x$metadata %>% 
  filter(n_errors > 0)

x$detectiondata %>% 
  filter(n_errors > 0)

x$gpsdata %>% 
  filter(n_errors > 0)

