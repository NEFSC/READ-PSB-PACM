library(tidyverse)

dir <- "data-raw/submissions/GARDLINE_20250815/"

deployments <- readxl::read_excel(file.path(dir, "raw/GRDLN_20250815_METADATA.xlsx"))
detections <- readxl::read_excel(file.path(dir, "raw/GRDLN_20250815_DETECTIONDATA.xlsx"))

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(deployments, file.path(dir, "clean/deployments.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detections.csv"), na = "")
