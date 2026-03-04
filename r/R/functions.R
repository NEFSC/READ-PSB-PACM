# subs --------------------------------------------------------------------

read_raw_file <- function (filepath) {
  read_csv(
    filepath,
    col_types = cols(.default = col_character())
  ) |>
    janitor::remove_empty("rows") |>
    mutate(row = row_number()) |>
    relocate(row) |>
    select(-starts_with("..."))
}

load_clean_file <- function (id, filepath, rules, codes, parse, clean = identity) {
  if (!file.exists(filepath)) {
    return(NULL)
  }

  raw <- read_raw_file(filepath)

  parsed <- raw |>
    clean() |>
    parse()

  validation <- validate_data(parsed, rules, codes)
  errors <- extract_validation_errors(validation, parsed)

  tibble(
    filepath = filepath,
    n_rows = nrow(raw),
    raw = list(raw),
    parsed = list(parsed),
    valid = nrow(errors) == 0,
    validation = list(validation),
    errors = list(errors),
    n_errors = nrow(errors)
  )
}

email_pattern <- "^[_a-z0-9-]+(\\.[_a-z0-9-]+)*@[a-z0-9-]+(\\.[a-z0-9-]+)*(\\.[a-z]{2,})$"

remap <- function (x, mapping, upper = TRUE) {
  if (upper) {
    x <- toupper(x)
  }
  ifelse(x %in% names(mapping), mapping[x], x)
}

load_submission <- function (id, format, skip, root_dir, codes) {
  if (!is.na(skip)) {
    warning(glue("Skipping submission {id} with format {format}"))
    return(NULL)
  } else if (format == "PACM_20240820") {
    return(load_submission_pacm(id, format, root_dir, codes))
  } else if (format == "MAKARA_1.2") {
    warning(glue("No loader implemented for submission {id} with format {format}, skipping"))
    return(NULL)
  } else {
    stop(glue("Unsupported submission format: {format}"))
  }
}

load_submission_pacm <- function (id, format, root_dir, codes) {
  clean_dir <- file.path(root_dir, id, "clean")
  stopifnot(dir.exists(clean_dir))

  metadata <- load_clean_file(
    id,
    filepath = file.path(clean_dir, "metadata.csv"),
    rules = submission_rules$metadata,
    codes = codes,
    parse = parse_metadata,
    clean = clean_metadata
  )

  detectiondata <- load_clean_file(
    id,
    filepath = file.path(clean_dir, "detectiondata.csv"),
    rules = submission_rules$detectiondata,
    codes = codes,
    parse = parse_detectiondata,
    clean = clean_detectiondata
  )

  gpsdata <- load_clean_file(
    id,
    filepath = file.path(clean_dir, "gpsdata.csv"),
    rules = submission_rules$gpsdata,
    codes = codes,
    parse = parse_gpsdata,
    clean = clean_gpsdata
  )

  list(
    id = id,
    metadata = list(metadata),
    detectiondata = list(detectiondata),
    gpsdata = list(gpsdata)
  )
}


# validators -------------------------------------------------------------

submission_rules <- list(
  metadata = validate::validator(
    UNIQUE_ID.missing = !is.na(UNIQUE_ID),
    UNIQUE_ID.duplicated = is_unique(UNIQUE_ID),
    # PROJECT.missing = !is.na(PROJECT),
    # DATA_POC_NAME.missing = !is.na(DATA_POC_NAME),
    # DATA_POC_AFFILIATION.missing = !is.na(DATA_POC_AFFILIATION),
    # DATA_POC_EMAIL.missing = !is.na(DATA_POC_EMAIL),
    # DATA_POC_EMAIL.invalid_email = grepl(email_pattern, DATA_POC_EMAIL),
    # STATIONARY_OR_MOBILE.missing = !is.na(STATIONARY_OR_MOBILE),
    # STATIONARY_OR_MOBILE.invalid_code = STATIONARY_OR_MOBILE %vin% codes[["STATIONARY_OR_MOBILE"]],
    PLATFORM_TYPE.missing = !is.na(PLATFORM_TYPE),
    PLATFORM_TYPE.invalid_code = PLATFORM_TYPE %vin% codes[["platform_types"]],
    # SITE_ID.missing = !is.na(SITE_ID),
    INSTRUMENT_TYPE.missing = !is.na(INSTRUMENT_TYPE),
    # INSTRUMENT_ID.missing = !is.na(INSTRUMENT_ID),
    # CHANNEL.missing_or_nonnumeric = !is.na(CHANNEL),
    MONITORING_START_DATETIME.missing_or_invalid_format = !is.na(MONITORING_START_DATETIME),
    MONITORING_START_DATETIME.out_of_range = in_range(
      MONITORING_START_DATETIME, min = ymd_hm(199001010000), max = now()
    ),
    MONITORING_START_DATETIME.start_greater_than_end = MONITORING_START_DATETIME <= MONITORING_END_DATETIME,
    MONITORING_END_DATETIME.missing_or_invalid_format = !is.na(MONITORING_END_DATETIME),
    MONITORING_END_DATETIME.out_of_range = in_range(
      MONITORING_END_DATETIME, min = ymd_hm(199001010000), max = now()
    ),
    # SOUNDFILES_TIMEZONE.missing = !is.na(SOUNDFILES_TIMEZONE),
    # SOUNDFILES_TIMEZONE.invalid_code = SOUNDFILES_TIMEZONE %in% codes[["TIMEZONE_ID"]],
    LATITUDE.missing_or_nonnumeric = if (STATIONARY_OR_MOBILE == "STATIONARY") !is.na(LATITUDE),
    LATITUDE.out_of_range = if (STATIONARY_OR_MOBILE == "STATIONARY") in_range(LATITUDE, -90, 90),
    LONGITUDE.missing_or_nonnumeric = if (STATIONARY_OR_MOBILE == "STATIONARY") !is.na(LONGITUDE),
    LONGITUDE.out_of_range = if (STATIONARY_OR_MOBILE == "STATIONARY") in_range(LONGITUDE, -180, 180),
    WATER_DEPTH_METERS.missing_or_nonnumeric = if (STATIONARY_OR_MOBILE == "STATIONARY") !is.na(WATER_DEPTH_METERS),
    WATER_DEPTH_METERS.is_negative = if (STATIONARY_OR_MOBILE == "STATIONARY") in_range(WATER_DEPTH_METERS, 0, Inf),
    RECORDER_DEPTH_METERS.is_negative = is.na(RECORDER_DEPTH_METERS) | in_range(RECORDER_DEPTH_METERS, 0, Inf),
    SAMPLING_RATE_HZ.missing_or_nonnumeric = !is.na(SAMPLING_RATE_HZ),
    SAMPLING_RATE_HZ.is_negative = in_range(RECORDER_DEPTH_METERS, 0, Inf),
    # RECORDING_DURATION_SECONDS.missing = !is.na(RECORDING_DURATION_SECONDS),
    # RECORDING_DURATION_SECONDS.is_negative = in_range(RECORDING_DURATION_SECONDS, 0, Inf),
    # RECORDING_INTERVAL_SECONDS.missing = !is.na(RECORDING_INTERVAL_SECONDS),
    # RECORDING_INTERVAL_SECONDS.is_negative = in_range(RECORDING_INTERVAL_SECONDS, 0, Inf),
    SAMPLE_BITS.nonnumeric = is.na(SAMPLE_BITS) | !is.na(as.numeric(SAMPLE_BITS))
    # SUBMITTER_NAME.missing = !is.na(SUBMITTER_NAME),
    # SUBMITTER_AFFILIATION.missing = !is.na(SUBMITTER_AFFILIATION),
    # SUBMITTER_EMAIL.missing = !is.na(SUBMITTER_EMAIL),
    # SUBMITTER_EMAIL.invalid_email = grepl(email_pattern, SUBMITTER_EMAIL),
    # SUBMISSION_DATE.missing_or_invalid_format = !is.na(SUBMISSION_DATE),
    # SUBMISSION_DATE.out_of_range = in_range(
    #   SUBMISSION_DATE, min = ymd(20200101), max = today()
    # )
  ),
  detectiondata = validate::validator(
    UNIQUE_ID.missing = !is.na(UNIQUE_ID),
    # UNIQUE_ID.invalid_code = UNIQUE_ID %vin% codes[["UNIQUE_ID"]],
    ANALYSIS_PERIOD_START_DATETIME.missing_or_invalid_format = !is.na(ANALYSIS_PERIOD_START_DATETIME),
    ANALYSIS_PERIOD_START_DATETIME.outside_monitoring_period = in_range(
      ANALYSIS_PERIOD_START_DATETIME, 
      min = floor_date(METADATA.MONITORING_START_DATETIME, "day") - days(1),
      max = floor_date(METADATA.MONITORING_END_DATETIME, "day") + days(2)
    ),
    ANALYSIS_PERIOD_START_DATETIME.start_greater_than_end = ANALYSIS_PERIOD_START_DATETIME <= ANALYSIS_PERIOD_END_DATETIME,
    ANALYSIS_PERIOD_END_DATETIME.missing_or_invalid_format = !is.na(ANALYSIS_PERIOD_END_DATETIME),
    # ANALYSIS_PERIOD_END_DATETIME.outside_monitoring_period = in_range(
    #   ANALYSIS_PERIOD_END_DATETIME, 
    #   min = floor_date(METADATA.MONITORING_START_DATETIME, "day") - days(1),
    #   max = floor_date(METADATA.MONITORING_END_DATETIME, "day") + days(2)
    # ),
    # ANALYSIS_TIME_ZONE.missing = !is.na(ANALYSIS_TIME_ZONE),
    # ANALYSIS_TIME_ZONE.invalid_code = ANALYSIS_TIME_ZONE %in% codes[["TIMEZONE_ID"]],
    SPECIES_CODE.missing = !is.na(SPECIES_CODE),
    SPECIES_CODE.invalid_code = SPECIES_CODE %vin% codes[["sound_sources"]],
    ACOUSTIC_PRESENCE.missing = !is.na(ACOUSTIC_PRESENCE),
    ACOUSTIC_PRESENCE.invalid_code = ACOUSTIC_PRESENCE %vin% codes[["detection_result_types"]],
    N_VALIDATED_DETECTIONS.is_negative = is.na(N_VALIDATED_DETECTIONS) | in_range(N_VALIDATED_DETECTIONS, 0, Inf),
    # CALL_TYPE_CODE.missing = ACOUSTIC_PRESENCE %vin% c("DETECTED", "POSSIBLY_DETECTED") & !is.na(CALL_TYPE_CODE),
    CALL_TYPE_CODE.invalid_code = all(unlist(strsplit(CALL_TYPE_CODE, ","))) %vin% codes[["call_types"]],
    # CALL_TYPE_CODE.invalid_code_for_species = CALL_TYPE_CODE %vin% codes[["call_types"]][[codes[["SPECIES_CODE"]] == SPECIES_CODE]],
    DETECTION_METHOD.missing = !is.na(DETECTION_METHOD),
    PROTOCOL_REFERENCE.missing = !is.na(PROTOCOL_REFERENCE),
    DETECTION_SOFTWARE_NAME.missing = !is.na(DETECTION_SOFTWARE_NAME),
    MIN_ANALYSIS_FREQUENCY_RANGE_HZ.missing_or_nonnumeric = !is.na(MIN_ANALYSIS_FREQUENCY_RANGE_HZ),
    MIN_ANALYSIS_FREQUENCY_RANGE_HZ.out_of_range = in_range(
      MIN_ANALYSIS_FREQUENCY_RANGE_HZ, 
      min = 0,
      max = METADATA.SAMPLING_RATE_HZ
    ),
    # MIN_ANALYSIS_FREQUENCY_RANGE_HZ.min_greater_than_max = MIN_ANALYSIS_FREQUENCY_RANGE_HZ <= MAX_ANALYSIS_FREQUENCY_RANGE_HZ,
    MAX_ANALYSIS_FREQUENCY_RANGE_HZ.missing_or_nonnumeric = !is.na(MAX_ANALYSIS_FREQUENCY_RANGE_HZ),
    MAX_ANALYSIS_FREQUENCY_RANGE_HZ.out_of_range = in_range(
      MAX_ANALYSIS_FREQUENCY_RANGE_HZ, 
      min = 0,
      max = METADATA.SAMPLING_RATE_HZ
    )
    # QC_PROCESSING.missing = !is.na(QC_PROCESSING),
    # QC_PROCESSING.invalid_code = QC_PROCESSING %in% codes[["QC_PROCESSING"]]
  ),
  gpsdata = validate::validator(
    UNIQUE_ID.missing = !is.na(UNIQUE_ID),
    # UNIQUE_ID.invalid_code = UNIQUE_ID %vin% codes[["UNIQUE_ID"]],
    DATETIME.missing_or_invalid_format = !is.na(DATETIME),
    # DATETIME.out_of_range = in_range(
    #   DATETIME, 
    #   min = floor_date(METADATA.MONITORING_START_DATETIME, "day") - days(30),
    #   max = floor_date(METADATA.MONITORING_END_DATETIME, "day") + days(30)
    # ),
    LATITUDE.missing_or_nonnumeric = !is.na(LATITUDE),
    LATITUDE.out_of_range = in_range(LATITUDE, -90, 90),
    LONGITUDE.missing_or_nonnumeric = !is.na(LONGITUDE),
    LONGITUDE.out_of_range = in_range(LONGITUDE, -180, 180)
  )
)

validate_data <- function (x, rules, codes) {
  out <- confront(
    x,
    rules,
    ref = list(codes = codes),
    key = "row"
  )
  
  # summarise by rule
  # aggregate(out, by = "rule") |>
  #   select(npass, nfail, nNA) |>
  #   print()
  
  out
}

extract_validation_errors <- function (x, data = NULL) {
  errors <- as.data.frame(x) |>
    filter(!value) |>
    arrange(row)

  if (!is.null(data) && nrow(errors) > 0) {
    errors <- errors |>
      mutate(
        column = sub("\\..*", "", name),
        actual = map2_chr(column, row, \(col, r) {
          if (col %in% names(data)) as.character(data[[col]][r]) else NA_character_
        })
      ) |>
      select(-column)
  }

  errors
}


# parsers ----------------------------------------------------------------

parse_metadata <- function (x) {
  x |>
    select(-starts_with("X")) |>
    mutate(
      across(
        c(MONITORING_START_DATETIME, MONITORING_END_DATETIME),
        ymd_hms
      ),
      across(
        c(LATITUDE, LONGITUDE, WATER_DEPTH_METERS,
          RECORDER_DEPTH_METERS, SAMPLING_RATE_HZ,
          RECORDING_DURATION_SECONDS, RECORDING_INTERVAL_SECONDS,
          SAMPLE_BITS),
        parse_number
      ),
      across(
        c(STATIONARY_OR_MOBILE, PLATFORM_TYPE),
        toupper
      )
    )
}

parse_detectiondata <- function (x) {
  x |>
    mutate(
      across(
        c(ANALYSIS_PERIOD_START_DATETIME, ANALYSIS_PERIOD_END_DATETIME),
        ymd_hms
      ),
      across(
        c(SPECIES_CODE, CALL_TYPE_CODE, QC_PROCESSING),
        toupper
      )
    )
}

parse_gpsdata <- function (x) {
  x |>
    mutate(
      across(c(DATETIME), ymd_hms),
      across(c(LATITUDE, LONGITUDE), parse_number)
    )
}


# cleaners ---------------------------------------------------------------

clean_metadata <- function (x) {
  x |>
    mutate(
      PLATFORM_TYPE = remap(PLATFORM_TYPE, c(
        "BOTTOM-MOUNTED" = "BOTTOM_MOUNTED_MOORING",
        "SURFACE-BUOY" = "MOORED_SURFACE_BUOY"
      )),
      INSTRUMENT_TYPE = remap(INSTRUMENT_TYPE, c(
        "COLMAR GP1190 HYDROPHONE" = "COLMAR",
        "OBSERVER" = "OBSERVER",
        "RSA-ORCA" = "RSA_ORCA"
      ))
      # SUBMISSION_DATE = str_sub(SUBMISSION_DATE, 1, 10)
    )
}

clean_detectiondata <- function (x) {
  x |> 
    rename(any_of(c(SPECIES_CODE = "SPECIES", CALL_TYPE_CODE = "CALL_TYPE"))) |> 
    mutate(
      ACOUSTIC_PRESENCE = remap(ACOUSTIC_PRESENCE, c(
        "N" = "NOT_DETECTED",
        "Y" = "DETECTED",
        "M" = "POSSIBLY_DETECTED",
        "P" = "POSSIBLY_DETECTED",
        "D" = "DETECTED"
      )),
      SPECIES_CODE = remap(SPECIES_CODE, c(
        "NARW" = "RIWH",
        "NRIWH" = "RIWH",
        "NRIW" = "RIWH",
        "BWGM" = "BWG",
        "MEME" = "MMME",
        "UNMY" = "UNBA" # unid mysticete -> unid baleen whale
      )),
      # CALL_TYPE_CODE = case_when(
      #   CALL_TYPE_CODE == "ODCLICK" & SPECIES_CODE == "UNDO" ~ "OD_CLICK_IMP", # use generic
      #   TRUE ~ CALL_TYPE_CODE
      # ),
      CALL_TYPE_CODE = remap(CALL_TYPE_CODE, c(
        BLARCH = "BLWH_ARCHD",
        BLMIX = "BLWH_MIX",
        BLSONG = "BLWH_SONG",
        FMUS = "OD_CLICK_FM", 
        FWDS = "FIWH_40HZ",
        FWMIX = "FIWH_MIX",
        FWPLS = "FIWH_20HZ",
        HWMIX = "HUWH_MIX",
        HWSOC = "HUWH_SOCIAL",
        HWSONG = "HUWH_SONG",
        ODCLICK = "OD_CLICK",
        ODBP = "OD_BURST_PULSE",
        ODBZ = "OD_BUZZ",
        ODMIX = "OD_MIX",
        ODWHIS = "OD_WHIS",
        SWDS = "SEWH_DS80HZ",
        UPCALL = "RW_UPCALL",
        MWPT = "MIWH_PT",
        SPFORG = "SPWH_FORG"
      ))
    )
}

clean_gpsdata <- function (x) {
  x
}


# formatting -------------------------------------------------------------

format_number <- function(x) {
  format(x, scientific = FALSE, big.mark = ",")
}

format_range <- function(x) {
  x <- na.omit(x)
  if (length(x) == 0) {
    return(NA_character_)
  }
  x_unique <- sort(unique(x))
  if (length(x_unique) == 1) {
    return(format_number(x_unique))
  }
  paste0(format_number(min(x_unique)), "-", format_number(max(x_unique)))
}

format_list <- function(x) {
  x <- na.omit(x)
  if (length(x) == 0) {
    return(NA_character_)
  }
  x_unique <- sort(unique(x))
  paste0(x_unique, collapse = ",")
}

