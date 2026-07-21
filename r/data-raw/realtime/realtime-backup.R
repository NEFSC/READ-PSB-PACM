# accidentally deleted all realtime analyses before receiving updated versions
# so caching them here for now using local database

library(tidyverse)
library(targets)

# set PORT=5432 in .env, then run: tar_make(makara_pacm)
makara_pacm <- tar_read(makara_pacm)

realtime_deployments <- read_csv("data-raw/realtime/realtime-deployments.csv") |> 
  mutate(deployment_id = glue::glue("{organization_code}:{deployment_code}"))

stopifnot(
  all(realtime_deployments$deployment_id %in% makara_pacm$deployments$deployment_id)
)

realtime_analyses <- makara_pacm$analyses |> 
  filter(deployment_id %in% realtime_deployments$deployment_id)

write_rds(realtime_analyses, "data-raw/realtime/realtime-analyses.rds")
# now load this back into pipeline
