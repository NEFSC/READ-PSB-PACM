# export inventory table for updating the deployment/inventory relations
# currently, relations between deployments and inventory are stored in two places:
#   - I_EQPMNT_DEPLOYMENT.INVENTORY_ID is the "primary" sensor
#   - I_EQPMNT_DEPLOYMENT.WHICH_SENSORS is a text-field referring to "secondary" sensors
#   - I_INVENTORY_DEPLOYMENT is a many-to-many between deployment and inventory, 
#     which duplicates both the "primary" and "secondary" sensor relationships
#   - I_EQPMNT_DEPLOYMENT.HAS_SENSORS_HOW_MANY is the total number of sensors,
#     which could be queried from I_INVENTORY_DEPLOYMENT
# proposed schema changes:
#   - remove INVENTORY_ID, WHICH_SENSORS, HAS_SENSORS_HOW_MANY from I_EQPMNT_DEPLOYMENT
#   - move DEPTH_RECORDER_METERS, ADJUSTABLE_SYSTEM_GAIN from I_EQPMNT_DEPLOYMENT
#     to I_INVENTORY_DEPLOYMENT since these are specific to (sensor,deployment)
#   - verify lists in WHICH_SENSORS are represented in I_INVENTORY_DEPLOYMENT

library(tidyverse)

# 1: fetch db (I_EQPMNT_DEPLOYMENT, I_EQPMNT_INVNTRY, I_INVENTORY_DEPLOYMENT)
dotenv::load_dot_env()
con <- DBI::dbConnect(
  odbc::odbc(),
  dsn = Sys.getenv("PACM_DB_DSN"),
  uid = Sys.getenv("PACM_DB_UID"), 
  pwd = Sys.getenv("PACM_DB_PWD"), 
  believeNRows = FALSE
)

db_dep <- as_tibble(DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.I_EQPMNT_DEPLOYMENT;"))
db_inv <- as_tibble(DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.I_EQPMNT_INVNTRY;"))
db_dep_inv <- as_tibble(DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.I_INVENTORY_DEPLOYMENT;"))

DBI::dbDisconnect(con)

# verify relations (fails)
stopifnot(
  all(db_dep_inv$DEPLOYMENT_ID %in% db_dep$DEPLOYMENT_ID),
  all(db_dep_inv$INVENTORY_ID %in% db_inv$INVENTORY_ID),
  all(db_dep$INVENTORY_ID %in% db_inv$INVENTORY_ID)
)

# ISSUE: db_dep_inv and db_dep both have unmatched db_inv.INVENTORY_ID
# FK relations are currently disabled
db_dep_inv %>% 
  anti_join(db_inv, by = "INVENTORY_ID")
db_dep %>% 
  anti_join(db_inv, by = "INVENTORY_ID")

# remove those from tables
exclude_inventory_id <- db_dep_inv %>% 
  anti_join(db_inv, by = "INVENTORY_ID") %>% 
  pull(INVENTORY_ID)
db_dep_inv <- filter(db_dep_inv, !INVENTORY_ID %in% exclude_inventory_id)
db_dep <- filter(db_dep, !INVENTORY_ID %in% exclude_inventory_id)

# verify relations (passes)
stopifnot(
  all(db_dep_inv$DEPLOYMENT_ID %in% db_dep$DEPLOYMENT_ID),
  all(db_dep_inv$INVENTORY_ID %in% db_inv$INVENTORY_ID),
  all(db_dep$INVENTORY_ID %in% db_inv$INVENTORY_ID)
)

# ISSUE: primary INVENTORY_ID for DEPLOYMENT_ID is not also in db_dep_inv
db_dep %>% 
  anti_join(db_dep_inv, by = c("DEPLOYMENT_ID", "INVENTORY_ID")) %>%
  write_csv("~/deployments-primary-sensor-missing.csv")

# 2: split I_EQPMNT_DEPLOYMENT.WHICH_SENSORS into rows
dep_sensors <- db_dep %>% 
  distinct(DEPLOYMENT_ID, WHICH_SENSORS) %>%
  separate_rows(WHICH_SENSORS, sep = ";") %>%
  mutate(WHICH_SENSORS = str_trim(WHICH_SENSORS)) %>% 
  distinct() %>% 
  filter(!is.na(WHICH_SENSORS), !str_trim(WHICH_SENSORS) == "") %>%  
  arrange(WHICH_SENSORS)
sensors_1 <- dep_sensors %>% 
  group_by(WHICH_SENSORS) %>%  
  summarise(DEPLOYMENT_ID = str_c(DEPLOYMENT_ID, collapse = ";")) %>% 
  arrange(WHICH_SENSORS) %>% 
  mutate(
    WHICH_SENSORS_2 = case_when(
      str_detect(WHICH_SENSORS, "VR2AR,") ~ str_replace(WHICH_SENSORS, "VR2AR,", "VR2AR"),
      str_detect(WHICH_SENSORS, "temperature.") ~ str_replace(WHICH_SENSORS, "temperature.", "temperature,"),
      TRUE ~ WHICH_SENSORS
    )
  )
sensors_2 <- sensors_1 %>% 
  separate_rows(WHICH_SENSORS_2, sep = ",") %>%
  mutate(WHICH_SENSORS_2 = str_trim(WHICH_SENSORS_2)) %>% 
  filter(!is.na(WHICH_SENSORS_2), !str_trim(WHICH_SENSORS_2) == "") %>% 
  arrange(WHICH_SENSORS_2)
sensors_2 %>%
  group_by(WHICH_SENSORS_2) %>% 
  summarise(DEPLOYMENT_ID = str_c(DEPLOYMENT_ID, collapse = ";")) %>% 
  arrange(WHICH_SENSORS_2) %>%
  select(DEPLOYMENT_ID, WHICH_SENSORS_2) %>% 
  write_csv("~/sensors.csv")
  view()
  
db_inv %>% 
  select(INVENTORY_ID, INVENTORY_TYPE_ID, MANUFACTURER, MNFCTR_SERIAL_NUMBER, MNFCTR_MODEL_NUMBER, MODEL_TYPE, ITEM_DESCRIPTION) %>% 
  arrange(MANUFACTURER, MNFCTR_SERIAL_NUMBER) %>% 
  write_csv("~/inventory.csv", na = "")

# 3: match I_EQPMNT_DEPLOYMENT.WHICH_SENSORS to I_EQPMNT_INVNTRY.INVENTORY_ID
# 4: match I_EQPMNT_DEPLOYMENT.WHICH_SENSORS to I_INVENTORY_DEPLOYMENT
