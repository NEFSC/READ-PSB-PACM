library(tidyverse)

dir <- "data-raw/submissions/DFOCA_20220712"

metadata <- read_csv(file.path(dir, "raw/DFOCA_METADATA_20220712.csv"), col_types = cols(.default = col_character()))

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(metadata, file.path(dir, "clean/metadata.csv"), na = "")
