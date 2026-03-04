options(tidyverse.quiet = TRUE)
tar_option_set(
  packages = c(
    "tarchetypes",
    "tidyverse",
    "lubridate",
    "janitor",
    "glue",
    "units",
    "patchwork",
    "logger",
    "readxl",
    "validate",
    "sf",
    "dotenv",
    "validate"
  ),
  controller = crew::crew_controller_local(workers = 12)
)