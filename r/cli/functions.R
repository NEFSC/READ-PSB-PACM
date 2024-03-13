noop <- function (x) x

# printing ----------------------------------------------------------------

hr <- function(length = 80) {
  str_c(rep("-", length), collapse = "")
}

# file system -------------------------------------------------------------

mkdirp <- function (x) {
  if (!dir.exists(x)) {
    log_info("creating directory: {x}")
    dir.create(x, showWarnings = FALSE, recursive = TRUE)
  }
}

create_logfile <- function (dir, id) {
  logfile <- file.path(dir, glue("{id}.log"))
  log_info("log file: {logfile}")
  logfile
}

copy_files <- function (src_dir, dest_dir) {
  files <- list.files(src_dir)
  
  mkdirp(dest_dir)
  
  # Loop through the list of files and copy each one to the destination directory
  for (file in files) {
    src_file <- file.path(src_dir, file)
    dest_file <- file.path(dest_dir, file)
    log_info("copying file: {src_file} -> {dest_file}")
    file.copy(src_file, dest_file, overwrite = TRUE)
  }
}

move_directory <- function (src_dir, dest_dir, overwrite = FALSE) {
  if (dir.exists(dest_dir)) {
    if (overwrite) {
      log_warn("overwriting existing directory: {dest_dir}")
      unlink(dest_dir, recursive = TRUE)
    } else {
      stop("directory already exists: {dest_dir}")
    }
  }
  log_info("moving directory: {src_dir} -> {dest_dir}")
  if (!file.rename(src_dir, dest_dir)) {
    log_error("failed to move directory")  
  }
}

read_raw_file <- function (filepath) {
  filename <- basename(filepath)
  
  read_csv(
    filepath, 
    col_types = cols(.default = col_character())
  ) %>% 
    mutate(
      row = row_number()
    ) %>% 
    relocate(row) %>%
    select(-starts_with("..."))
}


# database ----------------------------------------------------------------

db_connect <- function () {
  log_info("connecting to database")
  con <- DBI::dbConnect(
    odbc::odbc(),
    dsn = Sys.getenv("PACM_DB_DSN"),
    uid = Sys.getenv("PACM_DB_UID"), 
    pwd = Sys.getenv("PACM_DB_PWD"), 
    believeNRows = FALSE
  )
  con
}


load_db_tables <- function () {
  con <- db_connect()
  
  log_info("fetching support tables from database")
  E_PACM_METADATA <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.E_PACM_METADATA;")
  I_EQPMNT_DEPLOYMENT <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.I_EQPMNT_DEPLOYMENT;")
  I_EQPMNT_INVNTRY <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.I_EQPMNT_INVNTRY;")
  S_EQPMNT_INVNTRY_TYPE <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.S_EQPMNT_INVNTRY_TYPE;")
  I_INVENTORY_DEPLOYMENT <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.I_INVENTORY_DEPLOYMENT;")
  I_RECORDING <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.I_RECORDING;")
  S_PROJECT <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.S_PROJECT;")
  S_SITE <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.S_SITE;")
  S_CALL_LIBRARY <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.S_CALL_LIBRARY;")
  S_SPECIES <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.S_SPECIES;")
  S_CALL_TYPE <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.S_CALL_TYPE;")
  S_TIMEZONE <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.S_TIMEZONE;")
  S_ORGANIZATION <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.S_ORGANIZATION;")
  S_POINT_OF_CONTACT <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.S_POINT_OF_CONTACT;")
  S_DETECTOR_SETTINGS <- DBI::dbGetQuery(con, "SELECT * FROM PAGROUP.S_DETECTOR_SETTINGS;")
  
  log_info("disconnecting")
  DBI::dbDisconnect(con)
  
  list(
    metadata = as_tibble(E_PACM_METADATA),
    deployment = as_tibble(I_EQPMNT_DEPLOYMENT),
    inventory = as_tibble(I_EQPMNT_INVNTRY),
    inventory_type = as_tibble(S_EQPMNT_INVNTRY_TYPE),
    inventory_deployment = as_tibble(I_INVENTORY_DEPLOYMENT),
    recording = as_tibble(I_RECORDING),
    project = as_tibble(S_PROJECT),
    site = as_tibble(S_SITE),
    species = as_tibble(S_SPECIES) %>% 
      select(SPECIES_ID, SPECIES_CODE = PACM_SPECIES_CODE) %>% 
      filter(!is.na(SPECIES_CODE)),
    call_type = as_tibble(S_CALL_TYPE) %>% 
      select(
        CALL_TYPE_ID, 
        CALL_TYPE_CODE = PACM_CALL_TYPE_CODE,
        SPECIES_CODE = PERMISSIBLE_PACM_SPECIES_CODES
      ) %>% 
      filter(!is.na(CALL_TYPE_CODE)) %>% 
      separate_rows(SPECIES_CODE),
    call_library = as_tibble(S_CALL_LIBRARY) %>% 
      select(
        CALL_LIBRARY_ID, 
        CALL_LIBRARY_NAME,
        CALL_LIBRARY_TYPE,
        SPECIES_CODE = PACM_SPECIES_CODES
      ) %>% 
      separate_rows(SPECIES_CODE),
    timezone = as_tibble(S_TIMEZONE),
    organization = as_tibble(S_ORGANIZATION),
    poc = as_tibble(S_POINT_OF_CONTACT),
    detector_settings = as_tibble(S_DETECTOR_SETTINGS)
  )
}


# validation --------------------------------------------------------------

load_codes <- function (db_tables) {
  log_info("loading codes")
  list(
    STATIONARY_OR_MOBILE = toupper(c("Stationary", "Mobile")),
    PLATFORM_TYPE = toupper(
      c("Bottom-Mounted", "Surface-buoy", "Electric-glider", "Wave-glider", 
        "Towed-array", "Linear-array", "Drifting-buoy")
    ),
    ACOUSTIC_PRESENCE = list(
      external = c("D", "P", "N", "M"),
      internal = c(-1, 0, 1, 2, 3)
    ),
    QC_PROCESSING = list(
      external = toupper(c("Real-time", "Archival")),
      internal = c("RT", "PP")
    ),
    ANALYSIS_GRANULARITY = c(
      "MINUTE", 
      "HOUR", 
      "DAY", 
      "WEEK", 
      "MONTH", 
      "YEAR", 
      "ENCOUNTER", 
      "GROUP VOCAL PERIOD", 
      "EVENT"
    ),
    SPECIES_CODE = db_tables$species$SPECIES_CODE,
    CALL_TYPE_CODE = select(db_tables$call_type, CALL_TYPE_CODE, SPECIES_CODE),
    TIMEZONE_ID = db_tables$timezone$TIMEZONE_ID,
    CALL_LIBRARY_ID = select(db_tables$call_library, CALL_LIBRARY_ID, SPECIES_CODE),
    ORGANIZATION_CODE = db_tables$organization$ORGANIZATION_CODE,
    POC_ID = db_tables$poc$POC_ID,
    DETECTOR_SETTINGS_ID = db_tables$detector_settings$DETECTOR_SETTINGS_ID
  )
}


# rules -------------------------------------------------------------------

pacm_rules <- function () {
  email_pattern <- "^[_a-z0-9-]+(\\.[_a-z0-9-]+)*@[a-z0-9-]+(\\.[a-z0-9-]+)*(\\.[a-z]{2,})$"
  
  list(
    external = list(
      metadata = validate::validator(
        UNIQUE_ID.missing = !is.na(UNIQUE_ID),
        UNIQUE_ID.duplicated = is_unique(UNIQUE_ID),
        UNIQUE_ID.already_exists = !UNIQUE_ID %vin% codes[["UNIQUE_ID"]],
        PROJECT.missing = !is.na(PROJECT),
        DATA_POC_NAME.missing = !is.na(DATA_POC_NAME),
        DATA_POC_AFFILIATION.missing = !is.na(DATA_POC_AFFILIATION),
        DATA_POC_EMAIL.missing = !is.na(DATA_POC_EMAIL),
        DATA_POC_EMAIL.invalid_email = grepl(email_pattern, DATA_POC_EMAIL),
        STATIONARY_OR_MOBILE.missing = !is.na(STATIONARY_OR_MOBILE),
        STATIONARY_OR_MOBILE.not_found = STATIONARY_OR_MOBILE %vin% codes[["STATIONARY_OR_MOBILE"]],
        PLATFORM_TYPE.missing = !is.na(PLATFORM_TYPE),
        PLATFORM_TYPE.not_found = PLATFORM_TYPE %vin% codes[["PLATFORM_TYPE"]],
        SITE_ID.missing = !is.na(SITE_ID),
        INSTRUMENT_TYPE.missing = !is.na(INSTRUMENT_TYPE),
        INSTRUMENT_ID.missing = !is.na(INSTRUMENT_ID),
        CHANNEL.missing_or_nonnumeric = !is.na(CHANNEL),
        MONITORING_START_DATETIME.missing_or_invalid_format = !is.na(MONITORING_START_DATETIME),
        MONITORING_START_DATETIME.out_of_range = in_range(
          MONITORING_START_DATETIME, min = ymd_hm(199001010000), max = now()
        ),
        MONITORING_START_DATETIME.start_greater_than_end = MONITORING_START_DATETIME <= MONITORING_END_DATETIME,
        MONITORING_END_DATETIME.missing_or_invalid_format = !is.na(MONITORING_END_DATETIME),
        MONITORING_END_DATETIME.out_of_range = in_range(
          MONITORING_END_DATETIME, min = ymd_hm(199001010000), max = now()
        ),
        SOUNDFILES_TIMEZONE.missing = !is.na(SOUNDFILES_TIMEZONE),
        SOUNDFILES_TIMEZONE.not_found = SOUNDFILES_TIMEZONE %in% codes[["TIMEZONE_ID"]],
        LATITUDE.missing_or_nonnumeric = if (STATIONARY_OR_MOBILE == "STATIONARY") !is.na(LATITUDE),
        LATITUDE.out_of_range = if (STATIONARY_OR_MOBILE == "STATIONARY") in_range(LATITUDE, -90, 90),
        LONGITUDE.missing_or_nonnumeric = if (STATIONARY_OR_MOBILE == "STATIONARY") !is.na(LONGITUDE),
        LONGITUDE.out_of_range = if (STATIONARY_OR_MOBILE == "STATIONARY") in_range(LONGITUDE, -180, 180),
        WATER_DEPTH_METERS.missing_or_nonnumeric = if (STATIONARY_OR_MOBILE == "STATIONARY") !is.na(WATER_DEPTH_METERS),
        WATER_DEPTH_METERS.is_negative = if (STATIONARY_OR_MOBILE == "STATIONARY") in_range(WATER_DEPTH_METERS, 0, Inf),
        RECORDER_DEPTH_METERS.is_negative = is.na(RECORDER_DEPTH_METERS) | in_range(RECORDER_DEPTH_METERS, 0, Inf),
        SAMPLING_RATE_HZ.missing_or_nonnumeric = !is.na(SAMPLING_RATE_HZ),
        SAMPLING_RATE_HZ.is_negative = in_range(RECORDER_DEPTH_METERS, 0, Inf),
        RECORDING_DURATION_SECONDS.missing = !is.na(RECORDING_DURATION_SECONDS),
        RECORDING_DURATION_SECONDS.is_negative = in_range(RECORDING_DURATION_SECONDS, 0, Inf),
        RECORDING_INTERVAL_SECONDS.missing = !is.na(RECORDING_INTERVAL_SECONDS),
        RECORDING_INTERVAL_SECONDS.is_negative = in_range(RECORDING_INTERVAL_SECONDS, 0, Inf),
        SAMPLE_BITS.nonnumeric = is.na(SAMPLE_BITS) | !is.na(as.numeric(SAMPLE_BITS)),
        SUBMITTER_NAME.missing = !is.na(SUBMITTER_NAME),
        SUBMITTER_AFFILIATION.missing = !is.na(SUBMITTER_AFFILIATION),
        SUBMITTER_EMAIL.missing = !is.na(SUBMITTER_EMAIL),
        SUBMITTER_EMAIL.invalid_email = grepl(email_pattern, SUBMITTER_EMAIL),
        SUBMISSION_DATE.missing_or_invalid_format = !is.na(SUBMISSION_DATE),
        SUBMISSION_DATE.out_of_range = in_range(
          SUBMISSION_DATE, min = ymd(20200101), max = today()
        )
      ),
      detectiondata = validate::validator(
        UNIQUE_ID.missing = !is.na(UNIQUE_ID),
        UNIQUE_ID.not_found = UNIQUE_ID %vin% codes[["UNIQUE_ID"]],
        ANALYSIS_PERIOD_START_DATETIME.missing_or_invalid_format = !is.na(ANALYSIS_PERIOD_START_DATETIME),
        ANALYSIS_PERIOD_START_DATETIME.outside_monitoring_period = in_range(
          ANALYSIS_PERIOD_START_DATETIME, 
          min = floor_date(METADATA.MONITORING_START_DATETIME, "day") - days(1),
          max = floor_date(METADATA.MONITORING_END_DATETIME, "day") + days(2)
        ),
        ANALYSIS_PERIOD_START_DATETIME.start_greater_than_end = ANALYSIS_PERIOD_START_DATETIME <= ANALYSIS_PERIOD_END_DATETIME,
        ANALYSIS_PERIOD_END_DATETIME.missing_or_invalid_format = !is.na(ANALYSIS_PERIOD_END_DATETIME),
        ANALYSIS_PERIOD_END_DATETIME.outside_monitoring_period = in_range(
          ANALYSIS_PERIOD_END_DATETIME, 
          min = floor_date(METADATA.MONITORING_START_DATETIME, "day") - days(1),
          max = floor_date(METADATA.MONITORING_END_DATETIME, "day") + days(2)
        ),
        ANALYSIS_TIME_ZONE.missing = !is.na(ANALYSIS_TIME_ZONE),
        ANALYSIS_TIME_ZONE.not_found = ANALYSIS_TIME_ZONE %in% codes[["TIMEZONE_ID"]],
        SPECIES_CODE.missing = !is.na(SPECIES_CODE),
        SPECIES_CODE.not_found = SPECIES_CODE %vin% codes[["SPECIES_CODE"]],
        ACOUSTIC_PRESENCE.missing = !is.na(ACOUSTIC_PRESENCE),
        ACOUSTIC_PRESENCE.not_found = ACOUSTIC_PRESENCE %vin% codes[["ACOUSTIC_PRESENCE"]][["external"]],
        N_VALIDATED_DETECTIONS.is_negative = is.na(N_VALIDATED_DETECTIONS) | in_range(N_VALIDATED_DETECTIONS, 0, Inf),
        CALL_TYPE_CODE.missing = !is.na(CALL_TYPE_CODE),
        CALL_TYPE_CODE.not_found_for_species = CALL_TYPE_CODE %vin% codes[["CALL_TYPE_CODE"]][[codes[["SPECIES_CODE"]] == SPECIES_CODE]],
        DETECTION_METHOD.missing = !is.na(DETECTION_METHOD),
        PROTOCOL_REFERENCE.missing = !is.na(PROTOCOL_REFERENCE),
        DETECTION_SOFTWARE_NAME.missing = !is.na(DETECTION_SOFTWARE_NAME),
        MIN_ANALYSIS_FREQUENCY_RANGE_HZ.missing_or_nonnumeric = !is.na(MIN_ANALYSIS_FREQUENCY_RANGE_HZ),
        MIN_ANALYSIS_FREQUENCY_RANGE_HZ.out_of_range = in_range(
          MIN_ANALYSIS_FREQUENCY_RANGE_HZ, 
          min = 0,
          max = METADATA.SAMPLING_RATE_HZ
        ),
        MIN_ANALYSIS_FREQUENCY_RANGE_HZ.min_greater_than_max = MIN_ANALYSIS_FREQUENCY_RANGE_HZ <= MAX_ANALYSIS_FREQUENCY_RANGE_HZ,
        MAX_ANALYSIS_FREQUENCY_RANGE_HZ.missing_or_nonnumeric = !is.na(MAX_ANALYSIS_FREQUENCY_RANGE_HZ),
        MAX_ANALYSIS_FREQUENCY_RANGE_HZ.out_of_range = in_range(
          MAX_ANALYSIS_FREQUENCY_RANGE_HZ, 
          min = 0,
          max = METADATA.SAMPLING_RATE_HZ
        ),
        QC_PROCESSING.missing = !is.na(QC_PROCESSING),
        QC_PROCESSING.not_found = QC_PROCESSING %in% codes[["QC_PROCESSING"]][["external"]]
      ),
      gpsdata = validate::validator(
        UNIQUE_ID.missing = !is.na(UNIQUE_ID),
        UNIQUE_ID.not_found = UNIQUE_ID %vin% codes[["UNIQUE_ID"]],
        DATETIME.missing_or_invalid_format = !is.na(DATETIME),
        DATETIME.out_of_range = in_range(
          DATETIME, 
          min = floor_date(METADATA.MONITORING_START_DATETIME, "day") - days(30),
          max = floor_date(METADATA.MONITORING_END_DATETIME, "day") + days(30)
        ),
        LATITUDE.missing_or_nonnumeric = !is.na(LATITUDE),
        LATITUDE.out_of_range = in_range(LATITUDE, -90, 90),
        LONGITUDE.missing_or_nonnumeric = !is.na(LONGITUDE),
        LONGITUDE.out_of_range = in_range(LONGITUDE, -180, 180)
      )
    ),
    internal = list(
      header = validate::validator(
        # DEPLOYMENT_ID.missing = !is.na(DEPLOYMENT_ID),
        # DEPLOYMENT_ID.not_found = DEPLOYMENT_ID %vin% codes[["DEPLOYMENT_ID"]],
        RECORDING_ID.missing = !is.na(RECORDING_ID),
        RECORDING_ID.not_found = RECORDING_ID %vin% codes[["RECORDING_ID"]],
        
        DETECTION_HEADER_ID.missing = !is.na(DETECTION_HEADER_ID),
        DETECTION_HEADER_ID.duplicated = is_unique(DETECTION_HEADER_ID),
        
        DATA_POC.missing = !is.na(DATA_POC),
        DATA_POC.invalid_email = grepl(email_pattern, DATA_POC),
        DATA_POC.not_found = DATA_POC %vin% codes[["POC_ID"]],
        SUBMITTER_POC.missing = !is.na(SUBMITTER_POC),
        SUBMITTER_POC.invalid_email = grepl(email_pattern, SUBMITTER_POC),
        SUBMITTER_POC.not_found = SUBMITTER_POC %vin% codes[["POC_ID"]],
        SUBMISSION_DATE.missing_or_invalid_format = !is.na(SUBMISSION_DATE),
        SUBMISSION_DATE.out_of_range = in_range(
          SUBMISSION_DATE, min = ymd(20200101), max = today()
        ),
        
        ANALYSIS_SAMPLING_RATE_HZ.missing = !is.na(ANALYSIS_SAMPLING_RATE_HZ),
        ANALYSIS_SAMPLING_RATE_HZ.is_negative = in_range(ANALYSIS_SAMPLING_RATE_HZ, 0, Inf),
        MIN_ANALYSIS_FREQUENCY_HZ.missing = !is.na(MIN_ANALYSIS_FREQUENCY_HZ),
        MIN_ANALYSIS_FREQUENCY_HZ.out_of_range = in_range(
          MIN_ANALYSIS_FREQUENCY_HZ, 
          min = 0,
          max = ANALYSIS_SAMPLING_RATE_HZ
        ),
        MIN_ANALYSIS_FREQUENCY_HZ.min_greater_than_max = MIN_ANALYSIS_FREQUENCY_HZ <= MAX_ANALYSIS_FREQUENCY_HZ,
        
        MAX_ANALYSIS_FREQUENCY_HZ.missing = !is.na(MAX_ANALYSIS_FREQUENCY_HZ),
        MAX_ANALYSIS_FREQUENCY_HZ.out_of_range = in_range(
          MAX_ANALYSIS_FREQUENCY_HZ, 
          min = 0,
          max = ANALYSIS_SAMPLING_RATE_HZ
        ),
        
        MONITORING_START_DATETIME.missing = !is.na(MONITORING_START_DATETIME),
        MONITORING_START_DATETIME.out_of_range = in_range(
          MONITORING_START_DATETIME, 
          min = ymd_hm(199001010000),
          max = now()
        ),
        MONITORING_START_DATETIME.start_greater_than_end = MONITORING_START_DATETIME <= MONITORING_END_DATETIME,
        MONITORING_END_DATETIME.missing = !is.na(MONITORING_END_DATETIME),
        MONITORING_END_DATETIME.out_of_range = in_range(
          MONITORING_END_DATETIME, 
          min = ymd_hm(199001010000),
          max = now()
        ),
        
        PRIMARY_ANALYST.missing = !is.na(PRIMARY_ANALYST),
        PRIMARY_ANALYST.invalid_email = grepl(email_pattern, PRIMARY_ANALYST),
        PRIMARY_ANALYST.not_found = PRIMARY_ANALYST %vin% codes[["POC_ID"]],
        SECONDARY_ANALYST.invalid_email = is.na(SECONDARY_ANALYST) | grepl(email_pattern, SECONDARY_ANALYST),
        SECONDARY_ANALYST.not_found = is.na(SECONDARY_ANALYST) | SECONDARY_ANALYST %vin% codes[["POC_ID"]],
        TERTIARY_ANALYST.invalid_email = is.na(TERTIARY_ANALYST) | grepl(email_pattern, TERTIARY_ANALYST),
        TERTIARY_ANALYST.not_found = is.na(TERTIARY_ANALYST) | TERTIARY_ANALYST %vin% codes[["POC_ID"]],
        
        ANALYSIS_TIMEZONE.missing = !is.na(ANALYSIS_TIMEZONE),
        ANALYSIS_TIMEZONE.not_found = ANALYSIS_TIMEZONE %vin% codes[["TIMEZONE_ID"]],
        
        DETECTION_METHOD.missing = !is.na(DETECTION_METHOD),
        PROTOCOL_REFERENCE.missing = !is.na(PROTOCOL_REFERENCE),
        DETECTOR_OUTPUT_FILENAME.missing = !is.na(DETECTOR_OUTPUT_FILENAME),
        SOFTWARE.missing = !is.na(SOFTWARE),
        DETECTOR_SETTINGS_ID.not_found = is.na(DETECTOR_SETTINGS_ID) | DETECTOR_SETTINGS_ID %vin% codes[["DETECTOR_SETTINGS_ID"]],
        
        ANALYSIS_GRANULARITY.missing = !is.na(ANALYSIS_GRANULARITY),
        ANALYSIS_GRANULARITY.not_found = ANALYSIS_GRANULARITY %vin% codes[["ANALYSIS_GRANULARITY"]],
        CALL_LIBRARY_ID.missing = !is.na(CALL_LIBRARY_ID),
        CALL_LIBRARY_ID.not_found = CALL_LIBRARY_ID %vin% codes[["CALL_LIBRARY_ID"]][["CALL_LIBRARY_ID"]],
        # CALL_LIBRARY_ID.not_found = CALL_LIBRARY_ID %vin% codes[["CALL_LIBRARY_ID"]][["CALL_LIBRARY_ID"]][[codes[["CALL_LIBRARY_ID"]][["SPECIES_CODE"]] == PACM_SPECIES_CODE]],
        QC_PROCESSING.missing = !is.na(QC_PROCESSING),
        QC_PROCESSING.not_found = QC_PROCESSING %in% codes[["QC_PROCESSING"]][["internal"]]
      ),
      detail = validate::validator(
        # DEPLOYMENT_ID.missing = !is.na(DEPLOYMENT_ID),
        # DEPLOYMENT_ID.not_found = DEPLOYMENT_ID %vin% codes[["DEPLOYMENT_ID"]],
        DETECTION_HEADER_ID.missing = !is.na(DETECTION_HEADER_ID),
        DETECTION_HEADER_ID.not_found = DETECTION_HEADER_ID %vin% codes[["DETECTION_HEADER_ID"]],
        
        ANALYSIS_PERIOD_START_DATETIME.missing = !is.na(ANALYSIS_PERIOD_START_DATETIME),
        ANALYSIS_PERIOD_START_DATETIME.outside_monitoring_period = in_range(
          ANALYSIS_PERIOD_START_DATETIME,
          min = floor_date(HEADER.MONITORING_START_DATETIME, "day"),
          max = floor_date(HEADER.MONITORING_END_DATETIME, "day") + days(1)
        ),
        ANALYSIS_PERIOD_START_DATETIME.start_greater_than_end = ANALYSIS_PERIOD_START_DATETIME <= ANALYSIS_PERIOD_END_DATETIME,
        ANALYSIS_PERIOD_END_DATETIME.missing = !is.na(ANALYSIS_PERIOD_END_DATETIME),
        ANALYSIS_PERIOD_END_DATETIME.outside_monitoring_period = in_range(
          ANALYSIS_PERIOD_END_DATETIME,
          min = floor_date(HEADER.MONITORING_START_DATETIME, "day"),
          max = floor_date(HEADER.MONITORING_END_DATETIME, "day") + days(1)
        ),
        ANALYSIS_PERIOD_EFFORT_SECONDS.missing = !is.na(ANALYSIS_PERIOD_EFFORT_SECONDS),
        ANALYSIS_PERIOD_EFFORT_SECONDS.is_negative = in_range(ANALYSIS_PERIOD_EFFORT_SECONDS, 0, Inf),
        ANALYSIS_PERIOD_EFFORT_SECONDS.greater_than_period_duration = ANALYSIS_PERIOD_EFFORT_SECONDS > as.numeric(difftime(ANALYSIS_PERIOD_END_DATETIME, ANALYSIS_PERIOD_END_DATETIME, units = "secs")),
        
        PACM_SPECIES_CODE.missing = !is.na(PACM_SPECIES_CODE),
        PACM_SPECIES_CODE.not_found = PACM_SPECIES_CODE %vin% codes[["SPECIES_CODE"]],
        PACM_SPECIES_CODE.call_library_not_found = PACM_SPECIES_CODE %vin% codes[["CALL_LIBRARY_ID"]][["PACM_SPECIES_CODE"]][[codes[["CALL_LIBRARY_ID"]][["CALL_LIBRARY_ID"]] == HEADER.CALL_LIBRARY_ID]],
        
        ACOUSTIC_PRESENCE.missing = !is.na(ACOUSTIC_PRESENCE),
        ACOUSTIC_PRESENCE.not_found = ACOUSTIC_PRESENCE %vin% codes[["ACOUSTIC_PRESENCE"]][["internal"]],
        
        N_VALIDATED_DETECTIONS.is_negative = is.na(N_VALIDATED_DETECTIONS) | in_range(N_VALIDATED_DETECTIONS, 0, Inf),
        N_TOTAL_DETECTIONS.is_negative = is.na(N_TOTAL_DETECTIONS) | in_range(N_TOTAL_DETECTIONS, 0, Inf),
        MIN_NUMBER_ANIMALS.is_negative = is.na(MIN_NUMBER_ANIMALS) | in_range(MIN_NUMBER_ANIMALS, 0, Inf),
        BEST_NUMBER_ANIMALS.is_negative = is.na(BEST_NUMBER_ANIMALS) | in_range(BEST_NUMBER_ANIMALS, 0, Inf),
        MAX_NUMBER_ANIMALS.is_negative = is.na(MAX_NUMBER_ANIMALS) | in_range(MAX_NUMBER_ANIMALS, 0, Inf),

        LOWER_FREQUENCY_HZ.is_negative = is.na(LOWER_FREQUENCY_HZ) | in_range(LOWER_FREQUENCY_HZ, 0, Inf),
        LOWER_FREQUENCY_HZ.lower_greater_than_upper = LOWER_FREQUENCY_HZ <= UPPER_FREQUENCY_HZ,
        UPPER_FREQUENCY_HZ.is_negative = is.na(UPPER_FREQUENCY_HZ) | in_range(UPPER_FREQUENCY_HZ, 0, Inf),

        DETECTION_LATITUDE.missing_or_nonnumeric = !is.na(DETECTION_LATITUDE),
        DETECTION_LATITUDE.out_of_range = in_range(DETECTION_LATITUDE, -90, 90),
        DETECTION_LONGITUDE.missing_or_nonnumeric = !is.na(DETECTION_LONGITUDE),
        DETECTION_LONGITUDE.out_of_range = in_range(DETECTION_LONGITUDE, -180, 180),

        PERPENDICULAR_DISTANCE_M.is_negative = is.na(PERPENDICULAR_DISTANCE_M) | in_range(PERPENDICULAR_DISTANCE_M, 0, Inf),
        PERPENDICULAR_DISTANCE_ERROR_M.is_negative = is.na(PERPENDICULAR_DISTANCE_ERROR_M) | in_range(PERPENDICULAR_DISTANCE_ERROR_M, 0, Inf),
        ANIMAL_DEPTH_ERROR.is_negative = is.na(ANIMAL_DEPTH_ERROR) | in_range(ANIMAL_DEPTH_ERROR, 0, Inf),
        ANIMAL_DEPTH.is_negative = is.na(ANIMAL_DEPTH) | in_range(ANIMAL_DEPTH, 0, Inf),
        N_SIGNALS_DEPTH_ESTIMATION.is_negative = is.na(N_SIGNALS_DEPTH_ESTIMATION) | in_range(N_SIGNALS_DEPTH_ESTIMATION, 0, Inf),

        PACM_CALL_TYPE_CODE.missing = !is.na(PACM_CALL_TYPE_CODE),
        PACM_CALL_TYPE_CODE.not_found_for_species = PACM_CALL_TYPE_CODE %vin% codes[["CALL_TYPE_CODE"]][["CALL_TYPE_CODE"]][[codes[["CALL_TYPE_CODE"]][["SPECIES_CODE"]] == PACM_SPECIES_CODE]],

        MAX_MAHALANOBIS_DISTANCE.is_negative = is.na(MAX_MAHALANOBIS_DISTANCE) | in_range(MAX_MAHALANOBIS_DISTANCE, 0, Inf)
      )
    )
  )
}


# transform ---------------------------------------------------------------

load_transformers <- function (dir) {
  transformers <- list(
    metadata = NULL,
    detectiondata = NULL,
    gpsdata = NULL,
    header = NULL,
    detail = NULL
  )
  filepath <- file.path(dir, "transform.R")
  
  if (!file.exists(filepath)) {
    return(transformers)
  }
  log_info("loading transformers: {filepath}")
  
  source(filepath, local = TRUE)
  if (exists("transform_metadata")) {
    transformers$metadata <- transform_metadata
  }
  if (exists("transform_detectiondata")) {
    transformers$detectiondata <- transform_detectiondata
  }
  if (exists("transform_gpsdata")) {
    transformers$gpsdata <- transform_gpsdata
  }
  if (exists("transform_header")) {
    transformers$header <- transform_header
  }
  if (exists("transform_detail")) {
    transformers$detail <- transform_detail
  }
  
  transformers
}

# parse -------------------------------------------------------------------

parse_external_metadata <- function (x) {
  x %>%
    select(-starts_with("X")) %>% 
    mutate(
      across(
        c(
          MONITORING_START_DATETIME,
          MONITORING_END_DATETIME,
        ),
        ymd_hms
      ),
      across(SUBMISSION_DATE, ymd),
      across(
        c(
          CHANNEL,
          LATITUDE,
          LONGITUDE,
          WATER_DEPTH_METERS,
          RECORDER_DEPTH_METERS,
          SAMPLING_RATE_HZ,
          RECORDING_DURATION_SECONDS,
          RECORDING_INTERVAL_SECONDS,
          SAMPLE_BITS
        ),
        parse_number
      ),
      across(
        c(STATIONARY_OR_MOBILE, PLATFORM_TYPE),
        toupper
      )
    )
}

parse_external_detectiondata <- function (x) {
  x %>% 
    mutate(
      across(
        c(
          ANALYSIS_PERIOD_START_DATETIME, 
          ANALYSIS_PERIOD_END_DATETIME
        ),
        ymd_hms
      ),
      across(
        c(
          ANALYSIS_PERIOD_EFFORT_SECONDS, 
          N_VALIDATED_DETECTIONS, 
          MIN_ANALYSIS_FREQUENCY_RANGE_HZ, 
          MAX_ANALYSIS_FREQUENCY_RANGE_HZ,
          ANALYSIS_SAMPLING_RATE_HZ,
          LOCALIZED_LATITUDE,
          LOCALIZED_LONGITUDE,
          DETECTION_DISTANCE_M
        ),
        parse_number
      ),
      across(
        c(SPECIES_CODE, CALL_TYPE_CODE, QC_PROCESSING),
        toupper
      )
    )
}

parse_internal_header <- function (x) {
  x %>% 
    mutate(
      across(
        c(
          MONITORING_START_DATETIME, 
          MONITORING_END_DATETIME
        ),
        ymd_hms
      ),
      across(
        c(SUBMISSION_DATE),
        ymd
      ),
      across(
        c(
          # DEPLOYMENT_ID,
          RECORDING_ID,
          DETECTION_HEADER_ID,
          ANALYSIS_SAMPLING_RATE_HZ,
          MIN_ANALYSIS_FREQUENCY_HZ,
          MAX_ANALYSIS_FREQUENCY_HZ,
          ANALYSIS_CHANNEL
        ),
        parse_number
      ),
      across(
        c(DATA_POC, SUBMITTER_POC, PRIMARY_ANALYST, SECONDARY_ANALYST, TERTIARY_ANALYST),
        toupper
      )
    )
}

parse_internal_detail <- function (x) {
  x %>% 
    mutate(
      across(
        c(
          ANALYSIS_PERIOD_START_DATETIME, 
          ANALYSIS_PERIOD_END_DATETIME
        ),
        ymd_hms
      ),
      across(
        c(
          # DEPLOYMENT_ID
          DETECTION_HEADER_ID,
          ANALYSIS_PERIOD_EFFORT_SECONDS,
          N_VALIDATED_DETECTIONS,
          N_TOTAL_DETECTIONS,
          # MIN_NUMBER_ANIMALS,
          # BEST_NUMBER_ANIMALS,
          # MAX_NUMBER_ANIMALS,
          # LOWER_FREQUENCY,
          # UPPER_FREQUENCY,
          # DETECTION_LATITUDE,
          # DETECTION_LONGITUDE,
          # PERPENDICULAR_DISTANCE_M,
          # PERPENDICULAR_DISTANCE_ERROR_M,
          # ANIMAL_DEPTH,
          MAX_MAHALANOBIS_DISTANCE
        ),
        parse_number
      )
    )
}


# validate --------------------------------------------------------------

validate_data <- function (x, rules, codes) {
  out <- confront(
    x,
    rules,
    ref = list(codes = codes),
    key = "row"
  )
  log_info("validation results:")
  cat("\n")
  aggregate(out, by = "rule") %>% 
    select(npass, nfail, nNA) %>% 
    print()
  cat("\n")
  out
}

extract_validation_errors <- function (x) {
  as.data.frame(x) %>% 
    filter(!value) %>% 
    arrange(row)
}

submission_is_valid <- function (x) {
  y <- bind_rows(x$data, .id = "type")
  sum(y$n_errors) == 0
}

# submission -------------------------------------------------------


load_submission <- function (id, type, db_tables, data_dir = Sys.getenv("PACM_DATA_DIR")) {
  root_dir <- file.path(data_dir, type)
  stopifnot(dir.exists(root_dir))
  
  create_processing_dir(id, type)
  
  dirs <- list(
    root = root_dir,
    raw = file.path(root_dir, "raw", id),
    processing = file.path(root_dir, "processing", id),
    processed = file.path(root_dir, "processed", id),
    rejected = file.path(root_dir, "rejected", id)
  )
  
  log_info("loading raw files: {dirs$raw}")
  
  raw_files <- list.files(dirs$raw)
  if (length(raw_files) == 0) {
    stop("raw directory is empty")
  }
  log_info("raw files: {str_c(raw_files, collapse = ', ')}")
  
  transformers <- load_transformers(dirs$raw)
  
  out <- list(
    id = id,
    type = type,
    dirs = dirs,
    db = db_tables
  )
  
  codes <- load_codes(db_tables)
  rules <- pacm_rules()
  if (type == "external") {
    codes <- c(codes, list(UNIQUE_ID = db_tables$metadata$UNIQUE_ID))
    
    metadata <- load_submission_files(
      id,
      files = file.path(dirs$raw, raw_files),
      pattern = "*_METADATA_*",
      rules = rules$external$metadata, 
      codes = codes, 
      parse = parse_external_metadata,
      transform = transformers$metadata
    )
    if (nrow(metadata) > 0) {
      metadata_unique_ids <- unlist(map(metadata$parsed, \(x) x$UNIQUE_ID))
      codes[["UNIQUE_ID"]] <- c(codes[["UNIQUE_ID"]], metadata_unique_ids)
    }
    join_metadata <- bind_rows(db_tables$metadata, bind_rows(metadata$parsed)) %>% 
      filter(!duplicated(UNIQUE_ID)) %>% 
      select(UNIQUE_ID, MONITORING_START_DATETIME, MONITORING_END_DATETIME, SAMPLING_RATE_HZ) %>% 
      rename_with(~ paste0("METADATA.", .x))
    detectiondata <- load_submission_files(
      id,
      files = file.path(dirs$raw, raw_files),
      pattern = "*_DETECTIONDATA_*",
      rules = rules$external$detectiondata, 
      codes = codes, 
      parse = parse_external_detectiondata,
      transform = transformers$detectiondata,
      join_data = join_metadata,
      join_by = c("UNIQUE_ID" = "METADATA.UNIQUE_ID")
    )
    
    out <- c(out, list(
      codes = codes,
      data = list(
        metadata = metadata,
        detectiondata = detectiondata
      )
    ))
  } else if (type == "internal") {
    codes <- c(codes, list(RECORDING_ID = db_tables$recording$RECORDING_ID))
    header <- load_submission_files(
      id,
      files = file.path(dirs$raw, raw_files),
      pattern = "*_HEADER_*",
      rules = rules$internal$header, 
      codes = codes, 
      parse = parse_internal_header,
      transform = transformers$header
    )
    if (nrow(header) > 0) {
      detection_header_ids <- unlist(map(header$parsed, \(x) x$DETECTION_HEADER_ID))
      codes[["DETECTION_HEADER_ID"]] <- detection_header_ids
    }
    join_header <- bind_rows(header$parsed) %>% 
      filter(!duplicated(DETECTION_HEADER_ID)) %>% 
      select(RECORDING_ID, DETECTION_HEADER_ID, MONITORING_START_DATETIME, MONITORING_END_DATETIME, CALL_LIBRARY_ID) %>% 
      rename_with(~ paste0("HEADER.", .x))
    
    detail <- load_submission_files(
      id,
      files = file.path(dirs$raw, raw_files),
      pattern = "*_DETAIL_*",
      rules = rules$internal$detail, 
      codes = codes, 
      parse = parse_internal_detail,
      transform = transformers$detail,
      join_data = join_header,
      join_by = c("DETECTION_HEADER_ID" = "HEADER.DETECTION_HEADER_ID")
    )
    
    out <- c(out, list(
      codes = codes,
      data = list(
        header = header,
        detail = detail
      )
    ))
  }
  
  rds_filename <- file.path(dirs$processing, glue("{id}.rds"))
  log_info("saving dataset to rds file: {rds_filename}")
  write_rds(out, rds_filename)
  
  log_info("copying raw files to processing directory")
  copy_files(dirs$raw, file.path(dirs$processing, "raw"))
  
  log_info("loading finished")
  out
}

load_submission_files <- function (id, files, pattern, rules, codes, parse, transform = NULL, join_data = NULL, join_by = NULL) {
  log_info("matching raw files to pattern: '{pattern}'")
  matching_files <- grep(pattern, files, value = TRUE)
  
  if (length(matching_files) == 0) {
    log_warn("no files found matching pattern '{pattern}'")
    return(tibble())
  }
  log_info("loading matching files: {str_c(basename(matching_files), collapse = ', ')}")
  
  df <- tibble(
    id = id,
    filepath = matching_files,
    filename = basename(filepath)
  ) |> 
    rowwise() |> 
    mutate(
      raw = list({
        log_info("reading: {filename}")
        read_raw_file(filepath)
      }),
      transformed = list({
        result <- raw
        if (!is.null(transform)) {
          log_info("transforming: {filename}")
          result <- transform(raw)
        }
        result
      }),
      parsed = list({
        log_info("parsing: {filename}")
        parse(transformed)
      }),
      joined = list({
        log_info("joining: {filename}")
        x <- parsed
        if (!is.null(join_data)) x <- left_join(x, join_data, by = join_by)
        x
      }),
      validation = list({
        log_info("validating: {filename}")
        validate_data(joined, rules, codes)
      }),
      validation_errors = list(extract_validation_errors(validation)),
      n_rows = nrow(raw),
      n_errors = nrow(validation_errors)
    ) |> 
    ungroup()
  
  log_info("loaded {nrow(df)} file(s) matching '{pattern}' (n_rows={sum(df$n_rows)}, n_errors={sum(df$n_errors)})")
  cat("\n")
  print(select(df, filename, n_rows, n_errors))
  cat("\n")
  
  df
}

export_submission <- function (x) {
  if (!submission_is_valid(x)) {
    log_warn("submission is not valid, skipping export")
    return(FALSE)
  }
  
  log_info("exporting submission to database import files")
  
  import_dir <- file.path(x$dirs$processing, "import")
  mkdirp(import_dir)
  existing_import_files <- list.files(import_dir)
  if (length(existing_import_files) > 0) {
    log_info("clearing import directory: {import_dir}")
    walk(list.files(import_dir, full.names = TRUE), unlink)
  }
  import_files <- c()
  
  if (x$type == "external") {
    if (nrow(x$data$metadata) > 0) {
      metadata_file <- file.path(import_dir, glue("{x$id}_METADATA.csv"))
      log_info("saving metadata file: {metadata_file}")
      import_files <- c(import_files, metadata_file)
      unnest(x$data$metadata[, "parsed"]) %>% 
        select(-row) %>% 
        write_csv(metadata_file, na = "", progress = FALSE)
    }
    
    if (nrow(x$data$detectiondata) > 0) {
      detectiondata_file <- file.path(import_dir, glue("{x$id}_DETECTIONDATA.csv"))
      log_info("saving detectiondata file: {detectiondata_file}")
      import_files <- c(import_files, detectiondata_file)
      unnest(x$data$detectiondata[, "parsed"]) %>% 
        select(-row) %>% 
        left_join(
          x$db[["species"]],
          by = "SPECIES_CODE"
        ) %>% 
        relocate(SPECIES_ID, .after = SPECIES_CODE) %>% 
        left_join(
          x$db[["call_type"]],
          by = c("CALL_TYPE_CODE", "SPECIES_CODE")
        ) %>% 
        relocate(CALL_TYPE_ID, .after = CALL_TYPE_CODE) %>% 
        select(-SPECIES_CODE, -CALL_TYPE_CODE) %>%
        write_csv(detectiondata_file, na = "", progress = FALSE)
    }
  } else if (x$type == "internal") {
    if (nrow(x$data$header) > 0) {
      header_file <- file.path(import_dir, glue("{x$id}_HEADER.csv"))
      log_info("saving header file: {header_file}")
      import_files <- c(import_files, header_file)
      x$data$header %>% 
        select(parsed) %>% 
        unnest(parsed) %>% 
        select(-row) %>% 
        write_csv(header_file, na = "", progress = FALSE)
    }
    
    if (nrow(x$data$detail) > 0) {
      detail_file <- file.path(import_dir, glue("{x$id}_DETAIL.csv"))
      log_info("saving detail file: {detail_file}")
      import_files <- c(import_files, detail_file)
      unnest(x$data$detail[, "parsed"]) %>% 
        select(-row) %>% 
        left_join(
          x$db[["species"]],
          by = c("PACM_SPECIES_CODE" = "SPECIES_CODE")
        ) %>% 
        relocate(SPECIES_ID, .after = PACM_SPECIES_CODE) %>% 
        left_join(
          x$db[["call_type"]],
          by = c("PACM_CALL_TYPE_CODE" = "CALL_TYPE_CODE", "PACM_SPECIES_CODE" = "SPECIES_CODE")
        ) %>% 
        relocate(CALL_TYPE_ID, .after = PACM_CALL_TYPE_CODE) %>%
        select(-PACM_SPECIES_CODE, -PACM_CALL_TYPE_CODE) %>%
        write_csv(detail_file, na = "", progress = FALSE)
    }
  }
  
  log_info("copying import files to global import folder")
  copy_files(import_dir, file.path(x$dirs$root, "import"))
  
  log_info("export finished")
}

move_submission <- function (x) {
  log_info("moving submission")
  
  if (submission_is_valid(x)) {
    log_warn("submission passed validation checks, moving to `processed`")
    dest_dir <- x$dirs$processed
  } else {
    log_warn("submission failed validation checks, moving to `rejected`")
    dest_dir <- x$dirs$rejected
  }
  
  move_directory(x$dirs$processing, dest_dir, TRUE)
  
  log_info("move finished")
}

qaqc_submission <- function (x) {
  log_info("generating qaqc report")
  
  qaqc_file <- glue("{x$id}_QAQC.html")
  log_info("generating qaqc report: {qaqc_file}")
  rmarkdown::render(
    input = "templates/qaqc.rmd", 
    output_file = qaqc_file,
    params = list(
      submission = x
    ),
    quiet = TRUE,
    envir = new.env()
  )
  qaqc_file_src <- file.path("templates", qaqc_file)
  qaqc_file_dst <- file.path(x$dirs$processing, qaqc_file)
  log_info("copying report file: {qaqc_file_src} -> {qaqc_file_dst}")
  file.copy(qaqc_file_src, qaqc_file_dst, overwrite = TRUE)
  log_info("deleting initial report file: {qaqc_file_src}")
  unlink(qaqc_file_src)
  
  log_info("qaqc report finished")
  qaqc_file
}

create_processing_dir <- function(id, type = c("external", "internal"), data_dir = Sys.getenv("PACM_DATA_DIR")) {
  processing_dir <- file.path(data_dir, type, "processing", id)
  if (!dir.exists(processing_dir)) {
    mkdirp(processing_dir)
  }
  processing_dir
}

process_submission <- function (id, type = c("external", "internal"), data_dir = Sys.getenv("PACM_DATA_DIR"), write_log = TRUE, db_tables = NULL) {
  type <- match.arg(type)
  
  log_info("processing submission: {type}/{id}")
  
  stopifnot(dir.exists(data_dir))
  stopifnot(dir.exists(file.path(data_dir, type)))
  
  if (is.null(db_tables)) {
    db_tables <- load_db_tables()
  }
  
  processing_dir <- create_processing_dir(id, type, data_dir)
  
  if (write_log) sink(create_logfile(processing_dir, id))
  
  x <- load_submission(id, type, db_tables)
  invisible(qaqc_submission(x))
  invisible(export_submission(x))
  
  if (write_log) sink()
  
  invisible(move_submission(x))
  
  log_info("processing finished")
}


