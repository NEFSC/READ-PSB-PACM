targets_templates <- list(
  tar_target(templates_metadata_file, file.path(data_dir, "templates/PACM_TEMPLATE_METADATA.xlsx"), format = "file"),
  tar_target(templates_detections_file, file.path(data_dir, "templates/PACM_TEMPLATE_DETECTIONDATA.xlsx"), format = "file"),
  tar_target(templates_gps_file, file.path(data_dir, "templates/PACM_TEMPLATE_GPSDATA.xlsx"), format = "file")
)