options(warn = -1, readr.show_progress = FALSE)
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(glue))
suppressPackageStartupMessages(library(janitor))
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(validate))
suppressPackageStartupMessages(library(logger))

log_appender(appender_stdout)

# references and functions ------------------------------------------------

rules <- list(
  metadata = validator(
    unique_id_missing = !is.na(UNIQUE_ID),
    unique_id_duplicate = is_unique(UNIQUE_ID),
    project_missing = !is.na(PROJECT),
    data_poc_name_missing = !is.na(DATA_POC_NAME),
    data_poc_affiliation_missing = !is.na(DATA_POC_AFFILIATION),
    data_poc_email_missing = !is.na(DATA_POC_EMAIL),
    stationary_or_mobile_missing = !is.na(STATIONARY_OR_MOBILE),
    stationary_or_mobile_invalid = STATIONARY_OR_MOBILE %vin% codes$STATIONARY_OR_MOBILE,
    platform_type_missing = !is.na(PLATFORM_TYPE),
    platform_type_invalid = PLATFORM_TYPE %vin% codes$PLATFORM_TYPE,
    site_id_missing = !is.na(SITE_ID),
    instrument_type_missing = !is.na(INSTRUMENT_TYPE),
    monitoring_start_datetime_missing = !is.na(MONITORING_START_DATETIME),
    monitoring_end_datetime_missing = !is.na(MONITORING_END_DATETIME),
    monitoring_start_datetime_inrange = in_range(as_date(MONITORING_START_DATETIME), min = ymd(19900101), max = today()),
    monitoring_end_datetime_inrange = in_range(as_date(MONITORING_END_DATETIME), min = ymd(19900101), max = today()),
    soundfiles_timezone_missing = !is.na(SOUNDFILES_TIMEZONE),
    latitude_missing = if (STATIONARY_OR_MOBILE == "STATIONARY") !is.na(LATITUDE),
    longitude_missing = if (STATIONARY_OR_MOBILE == "STATIONARY") !is.na(LONGITUDE),
    sampling_rate_hz_missing = !is.na(SAMPLING_RATE_HZ),
    recording_duration_seconds_missing = !is.na(RECORDING_DURATION_SECONDS),
    recording_interval_seconds_missing = !is.na(RECORDING_INTERVAL_SECONDS),
    submitter_name_missing = !is.na(SUBMITTER_NAME),
    submitter_affiliation_missing = !is.na(SUBMITTER_AFFILIATION),
    submitter_email_missing = !is.na(SUBMITTER_EMAIL),
    submission_date_missing = !is.na(SUBMISSION_DATE)
  ),
  detectiondata = validator(
    unique_id_missing = !is.na(UNIQUE_ID),
    # unique_id_not_in_metadata = unique_id %vin% unique_ids,
    analysis_period_start_datetime_missing = !is.na(ANALYSIS_PERIOD_START_DATETIME_MISSING),
    analysis_period_end_datetime_missing = !is.na(ANALYSIS_PERIOD_END_DATETIME_MISSING),
    # analysis_period_effort_seconds_missing = !is.na(analysis_period_effort_seconds),
    species_missing = !is.na(SPECIES),
    acoustic_presence_missing = !is.na(ACOUSTIC_PRESENCE),
    analysis_sampling_rate_hz_missing = !is.na(ANALYSIS_SAMPLING_RATE_HZ),
    species_valid = SPECIES %vin% codes$SPECIES,
    acoustic_presence_valid = ACOUSTIC_PRESENCE %vin% codes$ACOUSTIC_PRESENCE,
    call_type_valid = call_type %in% codes$CALL_TYPE
    # qc_processing_valid = qc_processing %in% codes$QC_PROCESSING
  )
)

codes <- list(
  STATIONARY_OR_MOBILE = toupper(c("Stationary", "Mobile")),
  PLATFORM_TYPE = toupper(
    c("Bottom-Mounted", "Surface-buoy", "Electric-glider", "Wave-glider", 
      "Towed-array", "Linear-array", "Drifting-buoy")
  ),
  ACOUSTIC_PRESENCE = c("D", "P", "N", "M"),
  SPECIES = c("91", "14", "45", "59", "75", "18", "67", "72", "4", "61", 
              "48", "33", "74", "26", "55", "69", "40", "76", "37", "31", "71", 
              "108", "84", "774", "90", "35", "36", "32", "47", "804", "21", 
              "15", "73", "17", "86", "56", "46", "3", "2", "13", "82", "77", 
              "49", "51", "34", "80", "12"),
  CALL_TYPE = c("99", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", 
                "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", 
                "23", "24", "98")
)

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

validate_data <- function (x, rules) {
  out <- confront(
    x,
    rules,
    ref = list(codes = codes),
    key = "row"
  )
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

parse_metadata <- function (x) {
  x %>%
    select(-starts_with("X")) %>% 
    mutate(
      across(
        c(
          MONITORING_START_DATETIME,
          MONITORING_END_DATETIME,
          SUBMISSION_DATE
        ),
        ymd_hms
      ),
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

parse_detectiondata <- function (x) {
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
          ANALYSIS_SAMPLING_RATE_HZ
        ),
        parse_number
      ),
      across(
        c(SPECIES),
        toupper
      )
    )
}

# detectiondata_validation
# summary(detectiondata_validation)
# as.data.frame(detectiondata_validation)
# values(detectiondata_validation)
# summary(detectiondata_validation)
# violating(detectiondata_parsed, detectiondata_validation)
# plot(detectiondata_validation)
# barplot(detectiondata_validation)
# aggregate(detectiondata_validation, by = "rule")
# aggregate(detectiondata_validation, by = "record")

# functions ----------------------------------------------------------------

copy_submission_files <- function (submission_dir, processed_dir) {
  files <- list.files(submission_dir)
  
  target_dir <- file.path(processed_dir, "submission")
  if (!dir.exists(target_dir)) {
    log_info("creating processed/submission folder: {target_dir}")
    dir.create(target_dir, showWarnings = FALSE, recursive = TRUE)
  }
  
  # Loop through the list of files and copy each one to the destination directory
  for (file in files) {
    file_src <- file.path(submission_dir, file)
    file_dst <- file.path(target_dir, file)
    log_info("copying file: {file_src} -> {file_dst}")
    file.copy(file_src, file_dst, overwrite = TRUE)
  }
}

get_submission_dir <- function (submission_id, data_dir) {
  if (!dir.exists(data_dir)) {
    stop(glue("data directory ('{data_dir}') not found"))
  }
  
  x <- file.path(data_dir, "submissions", submission_id)
  
  if (!dir.exists(x)) {
    stop(glue("submission directory ('{x}') not found"))
  }
  
  x
}

get_processed_dir <- function (submission_id, data_dir) {
  if (!dir.exists(data_dir)) {
    stop(glue("data directory ('{data_dir}') not found"))
  }
  
  x <- file.path(data_dir, "processed", submission_id)
  
  if (!dir.exists(x)) {
    log_info("creating processed directory: {x}")
    dir.create(x, showWarnings = FALSE, recursive = TRUE)
  }
  dir.create(file.path(x, "submission"), showWarnings = FALSE, recursive = TRUE)
  
  x
}

split_submission_id <- function (x) {
  x_split <- unlist(str_split(x, pattern = "_", n = 2))
  if (length(x_split) != 2) {
    stop(glue("invalid submission id ('{x}'), expected '<ORGANIZATION CODE>_<YYYYMMDD>'"))
  }
  list(
    affiliation = x_split[1],
    date = x_split[2]
  )
}

load_submission <- function (submission_id, data_dir, write_log = !interactive()) {
  submission_dir <- get_submission_dir(submission_id, data_dir)
  processed_dir <- get_processed_dir(submission_id, data_dir)

  if (write_log) {
    logfile <- file.path(processed_dir, "submission_load.log")
    log_info("log file: {logfile}")
    sink(logfile)
  }
  log_info("loading submission")
  log_info("starting: {now(tz = 'US/Eastern')}")
  log_info("submission id: {submission_id}")
  log_info("data directory: {data_dir}")
  log_info("submission directory: {submission_dir}")
  log_info("processed directory: {processed_dir}")
  
  submission_files <- list.files(submission_dir)
  if (length(submission_files) == 0) {
    stop("submission directory is empty")
  }
  log_info("submission files: {str_c(submission_files, collapse = ', ')}")
  
  noop <- function (x) x
  
  rm(transform_metadata, transform_detectiondata, transform_gpsdata)
  if ("transform.R" %in% submission_files) {
    log_info("loading transformers")
    source(file.path(submission_dir, "transform.R"))
  }
  
  if (!exists("transform_metadata")) {
    transform_metadata <- noop
  }
  if (!exists("transform_detectiondata")) {
    transform_detectiondata <- noop
  }
  if (!exists("transform_gpsdata")) {
    transform_gpsdata <- noop
  }
  
  log_info("processing metadata")
  metadata_files <- grep("*_METADATA_*", submission_files, value = TRUE)
  if (length(metadata_files) > 0) {
    metadata <- tibble(
      submission_id = submission_id,
      filename = metadata_files
    ) |> 
      rowwise() |> 
      mutate(
        raw = list({
          log_info("{filename}: reading")
          read_raw_file(file.path(submission_dir, filename))
        }),
        transformed = list({
          log_info("{filename}: transforming")
          transform_metadata(raw)
        }),
        parsed = list({
          log_info("{filename}: parsing")
          parse_metadata(transformed)
        }),
        validation = list({
          log_info("{filename}: validating")
          validate_data(parsed, rules$metadata)
        }),
        validation_errors = list(extract_validation_errors(validation)),
        n_rows = nrow(raw),
        n_errors = nrow(validation_errors)
      ) |> 
      ungroup()
    log_info("loaded {nrow(metadata)} metadata file(s) (n_rows={sum(metadata$n_rows)}, n_errors={sum(metadata$n_errors)})")
    cat("\n")
    print(select(metadata, filename, n_rows, n_errors))
    cat("\n")
  } else {
    metadata <- tibble()
    log_warn("no metadata files found")
  }
  
  log_info("processing detection data")
  detectiondata_files <- grep("*_DETECTIONDATA_*", submission_files, value = TRUE)
  if (length(detectiondata_files) > 0) {
    detectiondata <- tibble(
      submission_id = submission_id,
      filename = detectiondata_files
    ) |> 
      rowwise() |> 
      mutate(
        raw = list({
          log_info("{filename}: reading")
          read_raw_file(file.path(submission_dir, filename))
        }),
        transformed = list({
          log_info("{filename}: transforming")
          transform_detectiondata(raw)
        }),
        parsed = list({
          log_info("{filename}: parsing")
          parse_detectiondata(transformed)
        }),
        validation = list({
          log_info("{filename}: validating")
          validate_data(parsed, rules$detectiondata)
        }),
        validation_errors = list(extract_validation_errors(validation)),
        n_rows = nrow(raw),
        n_errors = nrow(validation_errors)
      ) |> 
      ungroup()
    log_info("loaded {nrow(detectiondata)} detection data file(s) (n_rows={sum(detectiondata$n_rows)}, n_errors={sum(detectiondata$n_errors)})")
    cat("\n")
    print(select(detectiondata, filename, n_rows, n_errors))
    cat("\n")
  } else {
    detectiondata <- tibble()
    log_warn("no detection data files found")
  }
  
  out <- list(
    submission_id = submission_id,
    metadata = metadata,
    detectiondata = detectiondata
  )

  rds_filename <- file.path(processed_dir, glue("{submission_id}.rds"))
  log_info("saving submission to rds file: {basename(rds_filename)}")
  write_rds(out, rds_filename)
  
  log_info("copying submission files to processed directory")
  copy_submission_files(submission_dir, processed_dir)
  
  log_info("done: {now(tz = 'US/Eastern')}")
  sink()
  out
}

export_submission <- function (x, data_dir, write_log = !interactive()) {
  submission_id <- x$submission_id
  processed_dir <- get_processed_dir(submission_id, data_dir)
  
  if (write_log) {
    logfile <- file.path(processed_dir, "submission_export.log")
    log_info("log file: {logfile}")
    sink(logfile)
  }
  log_info("exporting submission")
  log_info("starting: {now(tz = 'US/Eastern')}")
  log_info("submission id: {submission_id}")
  
  submission_split <- split_submission_id(submission_id)
  submission_affiliation <- submission_split[1]
  submission_date <- submission_split[2]
  
  log_info("data directory: {data_dir}")
  log_info("processed directory: {processed_dir}")
  
  import_dir <- file.path(processed_dir, "import")
  if (!exists(import_dir)) {
    log_info("creating import directory: {import_dir}")
    dir.create(import_dir, showWarnings = FALSE, recursive = TRUE)
  }
  import_files <- c()
  
  if (nrow(x$metadata) > 0) {
    metadata_file <- file.path(import_dir, glue("{submission_affiliation}_METADATA_{submission_date}.csv"))
    log_info("saving metadata file: {metadata_file}")
    import_files <- c(import_files, metadata_file)
    x$metadata %>% 
      select(parsed) %>% 
      unnest(parsed) %>% 
      select(-row) %>% 
      write_csv(metadata_file, na = "", progress = FALSE)
  } else {
    log_info("no metadata found")
  }
  
  if (nrow(x$detectiondata) > 0) {
    detectiondata_file <- file.path(import_dir, glue("{submission_affiliation}_DETECTIONDATA_{submission_date}.csv"))
    log_info("saving detectiondata file: {detectiondata_file}")
    import_files <- c(import_files, detectiondata_file)
    x$detectiondata %>% 
      select(parsed) %>% 
      unnest(parsed) %>% 
      select(-row) %>% 
      write_csv(detectiondata_file, na = "", progress = FALSE)
  } else {
    log_info("no detection data found")
  }
  
  log_info("done: {now(tz = 'US/Eastern')}")
  sink()
  
  import_files
}

qaqc_submission <- function (x, data_dir, write_log = !interactive()) {
  submission_id <- x$submission_id
  processed_dir <- get_processed_dir(submission_id, data_dir)
  
  if (write_log) {
    logfile <- file.path(processed_dir, "submission_qaqc.log")
    log_info("log file: {logfile}")
    sink(logfile)
  }
  log_info("generating submission qaqc report")
  log_info("starting: {now(tz = 'US/Eastern')}")
  log_info("submission id: {submission_id}")
  
  submission_split <- split_submission_id(submission_id)
  submission_affiliation <- submission_split[1]
  submission_date <- submission_split[2]
  
  log_info("data directory: {data_dir}")
  log_info("processed directory: {processed_dir}")
  
  qaqc_dir <- file.path(processed_dir, "qaqc")
  if (!exists(qaqc_dir)) {
    log_info("creating qaqc directory: {qaqc_dir}")
    dir.create(qaqc_dir, showWarnings = FALSE, recursive = TRUE)
  }
  
  qaqc_file <- glue("{submission_affiliation}_QAQC_{submission_date}.html")
  log_info("generating qaqc report file: {qaqc_file}")
  rmarkdown::render(
    input = "templates/submission-qaqc.rmd", 
    # output_format = "html",
    output_file = qaqc_file,
    params = list(
      data_dir = data_dir,
      submission_id = submission_id
    ),
    quiet = TRUE,
    envir = new.env()
  )
  qaqc_file_src <- file.path("templates", qaqc_file)
  qaqc_file_dst <- file.path(qaqc_dir, qaqc_file)
  log_info("copying report file: {qaqc_file_src} -> {qaqc_file_dst}")
  file.copy(qaqc_file_src, qaqc_file_dst, overwrite = TRUE)
  log_info("deleting initial report file: {qaqc_file_src}")
  unlink(qaqc_file_src)
  
  log_info("done: {now(tz = 'US/Eastern')}")
  sink()
  
  qaqc_file
}
 
process_submission <- function (submission_id, data_dir, write_log = !interactive()) {
  log_info("submission_id: {submission_id}")
  x <- load_submission(submission_id, data_dir, write_log)
  invisible(qaqc_submission(x, data_dir, write_log))
  invisible(export_submission(x, data_dir, write_log))
}

# cli --------------------------------------------------------------------

data_dir <- "~/data/pacm"

submission_ids <- list.dirs(file.path(data_dir, "submissions"), full.names = FALSE, recursive = FALSE)

walk(submission_ids, function (submission_id) {
  process_submission(submission_id, data_dir, TRUE)
})
x <- load_submission("JASCO_20220819", data_dir)
process_submission("JASCO_20220819", data_dir, TRUE)


all_detections <- map_df(submission_ids, function (x) {
  y <- read_rds(file.path(data_dir, "processed", x, glue("{x}.rds")))
  y$detectiondata
})

all_detections %>% 
  select(submission_id, filename, parsed) %>% 
  unnest(parsed) %>% 
  distinct(submission_id, filename, SPECIES, CALL_TYPE) %>% 
  write_csv("~/submissions-call-types.csv")
