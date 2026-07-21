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

load_legacy <- function (id, format, skip, root_dir, codes) {
  if (!is.na(skip)) {
    warning(glue("Skipping submission {id} with format {format}"))
    return(NULL)
  } else if (format == "PACM_20240820") {
    return(load_legacy_pacm(id, format, root_dir, codes))
  } else if (format == "MAKARA_1.2") {
    warning(glue("No loader implemented for submission {id} with format {format}, skipping"))
    return(NULL)
  } else {
    stop(glue("Unsupported submission format: {format}"))
  }
}

load_legacy_pacm <- function (id, format, root_dir, codes) {
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


# derivations ------------------------------------------------------------

# these are shared by every submission source: given deployments (or GPS
# positions) already in the common shape, derive sites and tracks the same way
# regardless of whether the data arrived as legacy or PARS. keeping them here
# rather than in a source file is what guarantees identical site ids across the
# migration.

# group stationary deployments into sites, splitting a site into versions when
# it moves more than max_distance_km from its previous position
derive_sites <- function (deployments, max_distance_km = 10) {
  deployments |>
    filter(deployment_type == "STATIONARY") |>
    select(organization_code, site, deployment_id, latitude, longitude, monitoring_start_datetime, monitoring_end_datetime) |>
    arrange(organization_code, site, monitoring_start_datetime) |>
    nest(versions = -c(organization_code, site)) |>
    mutate(
      versions = map(versions, function (deps) {
        deps_sf <- st_as_sf(deps, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE, sf_column_name = "deployment_geometry")
        n <- nrow(deps_sf)
        geoms <- st_geometry(deps_sf)
        if (n <= 1) {
          deps$dist_to_prev_km <- 0
          deps$site_version <- 1
        } else {
          dist_to_prev_km <- c(0, vapply(seq(2, n, by = 1), function (i) {
            as.numeric(st_distance(geoms[i], geoms[i - 1])) / 1000
          }, numeric(1)))
          deps$dist_to_prev_km <- dist_to_prev_km
          deps$site_version <- cumsum(dist_to_prev_km > max_distance_km) + 1
        }
        deps |>
          nest(deployments = -site_version) |>
          mutate(
            site_latitude = map_dbl(deployments, ~ first(.$latitude)),
            site_longitude = map_dbl(deployments, ~ first(.$longitude)),
            n_deployments = map_int(deployments, nrow)
          )
      })
    ) |>
    unnest(versions) |>
    group_by(site) |>
    mutate(
      n_versions = max(site_version),
      site_id = if_else(
        n_versions > 1,
        glue("{organization_code}:{site}:{site_version}"),
        glue("{organization_code}:{site}")
      )
    ) |>
    relocate(site_id, .before = site) |>
    ungroup() |>
    select(-n_versions)
}

# build one track per deployment from GPS positions, thinned to the first fix
# in each hour. positions must already be shaped as
# deployment_code, datetime, latitude, longitude
#
# a track is a MULTILINESTRING of one or more segments. segments exist because
# PARS gpsdata carries no effort flag: a break in effort is visible only as an
# absence of positions, and without splitting there the track is drawn straight
# through port calls and off-effort transits.
#
# the break is defined in whole days rather than hours because that is what a
# break in effort actually is - a day with no positions. duration alone does
# not separate the two cases: in the towed array surveys, gaps *within* a leg
# reach 26.7 h while genuine leg boundaries start at 29.6 h, so any hour
# threshold that works does so by sitting in a three-hour window, and would
# start mis-splitting the moment a survey recorded a slightly longer gap
derive_tracks <- function (positions, deployments, max_gap_days = 1) {
  track_positions <- positions |>
    arrange(deployment_code, datetime)

  # aggregate to hourly positions (first position in each hour)
  track_positions_hourly <- track_positions |>
    mutate(
      datetime_hour = floor_date(datetime, unit = "hour")
    ) |>
    group_by(deployment_code, datetime_hour) |>
    slice_min(order_by = datetime, n = 1) |>
    ungroup() |>
    select(-datetime_hour)

  track_segments <- track_positions_hourly |>
    arrange(deployment_code, datetime) |>
    group_by(deployment_code) |>
    mutate(
      gap_days = as.numeric(as_date(datetime) - lag(as_date(datetime))),
      segment = cumsum(coalesce(gap_days > max_gap_days, FALSE)) + 1
    ) |>
    # a lone position cannot form a line; dropping it loses a vertex but never
    # invents one, and the alternative is a cast failure
    group_by(deployment_code, segment) |>
    filter(n() >= 2) |>
    ungroup() |>
    select(-gap_days)

  # convert to sf linestrings, one per segment, then collect each deployment's
  # segments into a single multilinestring.
  #
  # do_union = FALSE throughout: st_union would node the lines where a track
  # crosses itself and drop coincident vertices, reporting more segments than
  # were surveyed. the towed GU1303 cruise has 7 legs and unioning reports 11
  track_segments_sf <- track_segments |>
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) |>
    arrange(deployment_code, segment, datetime) |>
    group_by(deployment_code, segment) |>
    summarise(
      start_datetime = min(datetime),
      end_datetime = max(datetime),
      start_latitude = first(latitude),
      start_longitude = first(longitude),
      end_latitude = last(latitude),
      end_longitude = last(longitude),
      do_union = FALSE,
      .groups = "drop_last"
    ) |>
    st_cast("LINESTRING")

  track_positions_hourly_sf <- track_segments_sf |>
    summarise(
      start_datetime = min(start_datetime),
      end_datetime = max(end_datetime),
      start_latitude = first(start_latitude),
      start_longitude = first(start_longitude),
      end_latitude = last(end_latitude),
      end_longitude = last(end_longitude),
      do_union = FALSE,
      .groups = "drop"
    ) |>
    st_cast("MULTILINESTRING")

  tracks <- track_positions_hourly_sf |>
    left_join(
      deployments |>
        select(organization_code, deployment_id, deployment_code),
      by = c("deployment_code")
    ) |>
    mutate(track_id = glue("{deployment_id}:TRACK"))

  stopifnot(
    all(!duplicated(tracks$track_id)),
    all(!duplicated(tracks$deployment_id))
  )

  tracks
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

