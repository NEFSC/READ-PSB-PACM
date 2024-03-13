targets_db <- list(
  tar_target(db_file, "data/database/db-tables.rds", format = "file"),
  tar_target(db_all, read_rds(db_file)),
  tar_target(db_recordings, {
    db_all$recording %>% 
      janitor::clean_names() %>% 
      mutate(recording_id = as.character(recording_id))
  }),
  tar_target(db_deployments, {
    db_all$deployment %>% 
      janitor::clean_names() %>% 
      mutate(deployment_id = as.character(deployment_id))
  }),
  tar_target(db_sites, {
    db_all$site %>% 
      janitor::clean_names()
  }),
  tar_target(db_projects, {
    db_all$project %>% 
      janitor::clean_names()
  }),
  tar_target(db_inventory, {
    db_all$inventory %>% 
      janitor::clean_names()
  }),
  tar_target(db_inventory_types, {
    db_all$inventory_type %>% 
      janitor::clean_names()
  })
)