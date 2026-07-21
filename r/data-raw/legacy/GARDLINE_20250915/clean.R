library(tidyverse)

dir <- "data-raw/submissions/GARDLINE_20250915/"

deployments <- readxl::read_excel(file.path(dir, "raw/20250915_GRDLN_20250915_PSO METADATA.xlsx"))
detections <- readxl::read_excel(file.path(dir, "raw/20250915_GRDLN_20250915_PSO DETECTIONDATA.xlsx"))

dir.create(file.path(dir, "clean"), showWarnings = FALSE)
write_csv(deployments, file.path(dir, "clean/deployments.csv"), na = "")
write_csv(detections, file.path(dir, "clean/detections.csv"), na = "")
