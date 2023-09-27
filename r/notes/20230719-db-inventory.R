# create new I_INVENTORY_DEPLOYMENT records for database
# based on content of WHICH_SENSORS
# QAQC using HOW_MANY

library(tidyverse)
library(janitor)


# database ----------------------------------------------------------------

db <- read_rds("~/Dropbox/Work/pacm/db/inventory/db-20230719-inventory.rds")

# COLLECTION_TECH_TYPE_ID inconsistencies
# needs to be removed from either I_EQPMNT_INVNTRY or S_EQPMNT_INVNTRY_TYPE
db$I_EQPMNT_INVNTRY %>%
  select(INVENTORY_ID, INVENTORY_TYPE_ID, `I_EQPMNT_INVNTRY.COLLECTION_TECH_TYPE_ID` = COLLECTION_TECH_TYPE_ID) %>%
  left_join(
    db$S_EQPMNT_INVNTRY_TYPE %>%
      select(INVENTORY_TYPE_ID, INVENTORY_TYPE_NAME, `S_EQPMNT_INVNTRY_TYPE.COLLECTION_TECH_TYPE_ID` = COLLECTION_TECH_TYPE_ID),
    by = "INVENTORY_TYPE_ID"
  ) %>%
  as_tibble() %>%
  filter(I_EQPMNT_INVNTRY.COLLECTION_TECH_TYPE_ID != S_EQPMNT_INVNTRY_TYPE.COLLECTION_TECH_TYPE_ID) %>%
  view()

db_inv <- db$I_EQPMNT_INVNTRY %>% 
  select(INVENTORY_ID, INVENTORY_TYPE_ID, COLLECTION_TECH_TYPE_ID, MANUFACTURER, ITEM_DESCRIPTION) %>% 
  left_join(
    db$S_EQPMNT_INVNTRY_TYPE %>% 
      select(INVENTORY_TYPE_ID, INVENTORY_TYPE_NAME),
    by = "INVENTORY_TYPE_ID"
  ) %>% 
  as_tibble()

db_inv_dep1 <- db$I_INVENTORY_DEPLOYMENT %>% 
  select(INVENTORY_DEPLOYMENT_ID, DEPLOYMENT_ID, INVENTORY_ID) %>% 
  as_tibble()

db_dep1 <- db$I_EQPMNT_DEPLOYMENT %>% 
  select(DEPLOYMENT_ID, INVENTORY_ID, PROJECT_ID, SITE_ID, HAS_SENSORS_HOW_MANY) %>% 
  as_tibble()

# only missing inventory are for SITE_ID=TEMP, ignore
db_dep1 %>% 
  anti_join(
    db_inv, by = "INVENTORY_ID"
  )
drop_deployment_id <- db_dep1 %>% 
  anti_join(
    db_inv, by = "INVENTORY_ID"
  ) %>% 
  pull(DEPLOYMENT_ID)
drop_inv_dep_id <- 3545
db_dep <- db_dep1 %>% 
  filter(!DEPLOYMENT_ID %in% drop_deployment_id)
db_inv_dep <- db_inv_dep1 %>% 
  filter(!DEPLOYMENT_ID %in% drop_deployment_id, !INVENTORY_DEPLOYMENT_ID %in% drop_inv_dep_id)

db_inv_dep %>% 
  anti_join(
    db_inv, by = "INVENTORY_ID"
  )

# qaqc
stopifnot(
  all(db_dep$INVENTORY_ID %in% db_inv$INVENTORY_ID),
  all(db_inv_dep$INVENTORY_ID %in% db_inv$INVENTORY_ID),
  all(db_inv_dep$DEPLOYMENT_ID %in% db_dep$DEPLOYMENT_ID)
)

# revisions ---------------------------------------------------------------

id_rev_1 <- read_csv("~/Dropbox/Work/pacm/db/inventory/revised-deployment-inventory.csv") %>% 
  rename(DEPLOYMENT_ID = `DEPLOYMENT IDs`)

# drop rows with blank INVENTORY_ID
# split INVENTORY_ID by comma
id_rev_2 <- id_rev_1 %>% 
  filter(!is.na(INVENTORY_ID)) %>% 
  separate_rows(INVENTORY_ID, sep = ", ")
stopifnot(all(nchar(id_rev_2$INVENTORY_ID) == 4))

# split DEPLOYMENT_ID by semicolon
id_rev_3 <- id_rev_2 %>% 
  separate_rows(DEPLOYMENT_ID, sep = ";") %>% 
  mutate(across(c(DEPLOYMENT_ID, INVENTORY_ID), as.numeric))
stopifnot(all(nchar(id_rev_3$DEPLOYMENT_ID) == 4))

stopifnot(
  id_rev_3 %>%
    filter(INVENTORY_ID != 1607) %>% 
    count(DEPLOYMENT_ID, INVENTORY_ID) %>% 
    pull(n) %>% 
    all(. == 1),
  # only INVENTORY_ID=1607 can be duplicated, but not more than twice
  id_rev_3 %>%
    filter(INVENTORY_ID == 1607) %>% 
    count(DEPLOYMENT_ID, INVENTORY_ID) %>% 
    pull(n) %>% 
    all(. %in% c(1, 2)),
  all(id_rev_3$DEPLOYMENT_ID %in% db_dep$DEPLOYMENT_ID),
  all(id_rev_3$INVENTORY_ID %in% db_inv$INVENTORY_ID)
)

# 27 rows in I_EQPMNT_DEPLOYMENT are missing primary inventory in I_INVENTORY_DEPLOYMENT
new_dep_inv_from_dep <- db_dep %>% 
  anti_join(db_inv_dep, by = c("DEPLOYMENT_ID", "INVENTORY_ID")) %>% 
  select(DEPLOYMENT_ID, INVENTORY_ID)
new_dep_inv_from_dep

# existing rows from WHICH_SENSORS found in I_INVENTORY_DEPLOYMENT
existing_dep_inv <- id_rev_3 %>% 
  semi_join(db_inv_dep, by = c("DEPLOYMENT_ID", "INVENTORY_ID"))
existing_dep_inv %>%
  select(DEPLOYMENT_ID, INVENTORY_ID) %>% 
  left_join(
    db_inv, by = "INVENTORY_ID"
  ) %>% 
  tabyl(INVENTORY_TYPE_NAME) %>% 
  adorn_totals()

# new rows from WHICH_SENSORS not found in I_INVENTORY_DEPLOYMENT
# excluding INVENTORY_ID=1607
new_dep_inv_not1607 <- id_rev_3 %>% 
  anti_join(db_inv_dep, by = c("DEPLOYMENT_ID", "INVENTORY_ID")) %>% 
  filter(INVENTORY_ID != 1607)
nrow(existing_dep_inv)
existing_dep_inv %>% 
  select(DEPLOYMENT_ID, INVENTORY_ID) %>% 
  left_join(
    db_inv, by = "INVENTORY_ID"
  ) %>% 
  tabyl(INVENTORY_TYPE_NAME) %>% 
  adorn_totals()

# existing I_INVENTORY_DEPLOYMENT rows for INVENTORY_ID=1607 not found in WHICH_SENSORS map
existing_dep_inv_1607 <- db_inv_dep %>% 
  filter(INVENTORY_ID == 1607) %>% 
  semi_join(id_rev_3, by = c("DEPLOYMENT_ID", "INVENTORY_ID"))

# existing WHICH_SENSORS mapped rows
existing_rev_1607 <- id_rev_3 %>% 
  filter(INVENTORY_ID == 1607) %>% 
  semi_join(db_inv_dep, by = c("DEPLOYMENT_ID", "INVENTORY_ID"))

# new I_INVENTORY_DEPLOYMENT rows for INVENTORY_ID=1607
new_dep_inv_1607 <- id_rev_3 %>% 
  filter(INVENTORY_ID == 1607) %>% 
  count(DEPLOYMENT_ID, name = "n_total") %>% 
  left_join(
    db_inv_dep %>% 
      filter(INVENTORY_ID == 1607) %>% 
      count(DEPLOYMENT_ID, name = "n_existing"),
    by = "DEPLOYMENT_ID"
  ) %>% 
  mutate(
    n_existing = coalesce(n_existing, 0),
    n_new = n_total - n_existing
  ) %>% 
  filter(n_new > 0) %>% 
  transmute(DEPLOYMENT_ID, INVENTORY_ID = 1607)

# combine
new_dep_inv <- bind_rows(
  new_dep_inv_from_dep,
  new_dep_inv_not1607,
  new_dep_inv_1607
)

new_dep_inv %>% 
  select(DEPLOYMENT_ID, INVENTORY_ID) %>% 
  left_join(
    db_inv, by = "INVENTORY_ID"
  ) %>% 
  tabyl(INVENTORY_TYPE_NAME) %>% 
  adorn_totals()

# check results
db_inv_dep_new <- db_inv_dep %>% 
  bind_rows(new_dep_inv)

stopifnot(
  db_inv_dep_new %>% 
    filter(INVENTORY_ID != 1607) %>% 
    count(DEPLOYMENT_ID, INVENTORY_ID) %>% 
    left_join(
      db_inv_dep %>% 
        filter(INVENTORY_ID != 1607) %>% 
        count(DEPLOYMENT_ID, INVENTORY_ID, name = "n_old"),
      by = c("DEPLOYMENT_ID", "INVENTORY_ID")
    ) %>% 
    filter(n_old < 2) %>% # exclude original duplicates
    pull(n) %>% 
    all(. == 1),
  # only INVENTORY_ID=1607 can be duplicated, but not more than twice
  db_inv_dep_new %>%
    filter(INVENTORY_ID == 1607) %>% 
    count(DEPLOYMENT_ID, INVENTORY_ID) %>% 
    pull(n) %>% 
    all(. %in% c(1, 2))
)

db_inv_dep %>% 
  filter(INVENTORY_ID != 1607) %>% 
  count(DEPLOYMENT_ID, INVENTORY_ID) %>% 
  filter(n > 1) %>% 
  left_join(
    db_inv, by = "INVENTORY_ID"
  ) %>% 
  select(DEPLOYMENT_ID, INVENTORY_ID, MANUFACTURER, INVENTORY_TYPE_NAME) %>% 
  left_join(db$I_EQPMNT_DEPLOYMENT, by = "DEPLOYMENT_ID") %>% 
  view()

db_inv_dep_new %>% 
  left_join(
    db_inv, by = "INVENTORY_ID"
  ) %>% 
  tabyl(INVENTORY_TYPE_NAME)

db_inv_dep_new %>% 
  count(DEPLOYMENT_ID) %>% 
  left_join(
    db_dep %>% 
      select(DEPLOYMENT_ID, HAS_SENSORS_HOW_MANY),
    by = "DEPLOYMENT_ID"
  ) %>% 
  filter(n != HAS_SENSORS_HOW_MANY)

db_inv_dep_new %>% 
  filter(INVENTORY_ID == 1607) %>% 
  count(DEPLOYMENT_ID, name = "n_inventory") %>% 
  tabyl(n_inventory)

# export ------------------------------------------------------------------

new_dep_inv %>% 
  select(DEPLOYMENT_ID, INVENTORY_ID) %>% 
  write_csv("~/Dropbox/Work/pacm/db/inventory/I_INVENTORY_DEPLOYMENT-new-rows-20230719.csv")