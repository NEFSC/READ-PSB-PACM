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

remap <- function (x, mapping, upper = TRUE) {
  if (upper) {
    x <- toupper(x)
  }
  ifelse(x %in% names(mapping), mapping[x], x)
}

# validators -------------------------------------------------------------

# retained: validate_data() and extract_validation_errors() below are shared
# with the PARS validator (pars-validate.R). the legacy `submission_rules` and
# the PACM/MAKARA loader they served were removed

validate_data <- function (x, rules, codes) {
  out <- confront(
    x,
    rules,
    ref = list(codes = codes),
    key = "row"
  )

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


# legacy PACM_20240820 -> PARS conversion -------------------------
#
# These take *parsed* legacy frames - the output of clean_*() |> parse_*() (the
# same chain the removed legacy loader used), with datetimes already resolved to
# UTC POSIXct and numeric fields numeric. Working from the resolved values (not
# the raw CSV strings) reuses that tested timezone handling, so the PARS path
# derives dates from exactly the instants the legacy path
# published from. Numeric fields stay numeric so coordinate precision survives;
# only datetimes and codes become strings. Functions are pure - frames in and
# out, no file access; each clean.R supplies its own organization_code
# and project_funding.

# a resolved POSIXct as a UTC ISO-8601 string with an explicit +0000 offset.
# the instant is already correct, so this only labels it (never re-shifts it)
legacy_stamp_utc <- function (x) {
  out <- format(x, "%Y-%m-%dT%H:%M:%S+0000", tz = "UTC")
  out[is.na(x)] <- NA_character_
  out
}

# free-text DETECTION_METHOD -> a `detectors` vocabulary code. two steps: the
# normalisation pacm.R already applies before publication (ported so the PARS
# path publishes the same value), then the code mapping below. iconv repairs the
# invalid UTF-8 in this column (87 rows) before any string work - without it
# toupper/str_detect raise on those bytes
# the normalised detector string maps to a PARS detectors code. two kinds:
# official codes (RPS/JASCO/etc. carried as supplements until upstream adopts
# them), and legacy detectors with no official code that we PRESERVE verbatim as
# supplement codes rather than collapsing to OTHER - so the published
# detection_method keeps the granularity the legacy dataset had (the detectors
# below survive pacm_data's normalisation untouched, matching the baseline)
LEGACY_DETECTOR_CODES <- c(
  "RPS" = "RPS",
  "JASCO" = "JASCO_CONTOUR_CLICK",
  "CHORUS_BIOSOUND" = "CHORUS_BIOSOUND",
  "PAMLAB/MANUAL" = "JASCO_PAMLAB",
  "MANUAL" = "MANUAL",
  # preserved legacy detectors (no official PARS code); kept distinct,
  # mirroring the device_type supplements
  "AUTOMATIC" = "AUTOMATIC",
  "AUTOMATIC/MANUAL" = "AUTOMATIC/MANUAL",
  "MATLAB" = "MATLAB",
  "MATCHED_FILTER" = "MATCHED_FILTER",
  "GILLESPIE_EDGE" = "GILLESPIE_EDGE",
  "TRITON/DFO TWD" = "TRITON/DFO TWD"
)

legacy_detector_code <- function (detection_method) {
  dm <- iconv(detection_method, "UTF-8", "UTF-8", sub = "")
  dm <- toupper(dm)
  published <- case_when(
    str_detect(dm, "JASCO") ~ "JASCO",
    dm == "AUTOMATIC AND MANUAL" ~ "AUTOMATIC/MANUAL",
    dm == "CUSTOM AUTOMATIC DETECTOR" ~ "AUTOMATIC",
    str_starts(dm, "PAMGUARD WHISTLE") ~ "PAMGUARD",
    dm == "PAMLAB, MANUAL" ~ "PAMLAB/MANUAL",
    dm == "PAMGUARD,MANUAL" ~ "PAMGUARD/MANUAL",
    str_detect(dm, "RPS CONTOUR AND CLICK DETECTORS") ~ "RPS",
    str_detect(dm, "MATLAB-BASED AUTOMATED DETECTOR ALGORITHM") ~ "MATLAB",
    str_detect(dm, "MATCHED-FILTER DATA-TEMPLATE DETECTION ALGORITHM") ~ "MATCHED_FILTER",
    TRUE ~ dm
  )
  # anything still not recognised -> OTHER (supplement), to be hand-remapped in a
  # submission's clean.R later
  unname(coalesce(LEGACY_DETECTOR_CODES[published], "OTHER"))
}

# CALL_TYPE_CODE elements that legacy abbreviated; every other value is already
# a valid code and passes through. lists are split, each element mapped, then
# rejoined in submitted order (order is meaningful)
LEGACY_CALL_TYPE_CODES <- c(
  "NBHF" = "OD_CLICK_NBHF",
  "HBMIX" = "HUWH_MIX",
  "BLARCH" = "BLWH_ARCHD",
  "BLSONG" = "BLWH_SONG"
)

legacy_call_type_code <- function (call_type_code) {
  vapply(call_type_code, function (value) {
    if (is.na(value)) return(NA_character_)
    parts <- str_trim(str_split(value, ",")[[1]])
    str_c(unname(coalesce(LEGACY_CALL_TYPE_CODES[parts], parts)), collapse = ",")
  }, character(1), USE.NAMES = FALSE)
}

legacy_to_pars_metadata <- function (metadata, organization_code,
                                     project_funding = NA_character_) {
  # most raw files name the platform identifier PLATFORM_NO, a few PLATFORM_ID;
  # ensure both exist so the coalesce below never references an absent column
  for (col in setdiff(c("PLATFORM_ID", "PLATFORM_NO"), names(metadata))) {
    metadata[[col]] <- NA_character_
  }

  metadata |>
    transmute(
      deployment_organization_code = organization_code,
      deployment_code = UNIQUE_ID,
      project_name = PROJECT,
      site_code = SITE_ID,
      monitoring_start_datetime = legacy_stamp_utc(MONITORING_START_DATETIME),
      monitoring_end_datetime = legacy_stamp_utc(MONITORING_END_DATETIME),
      deployment_platform_type_code = PLATFORM_TYPE,
      deployment_platform_id = coalesce(PLATFORM_ID, PLATFORM_NO),
      deployment_water_depth_m = WATER_DEPTH_METERS,
      deployment_latitude = LATITUDE,
      deployment_longitude = LONGITUDE,
      dynamic_management_platform = NA_character_,
      deployment_url = NA_character_,
      recording_device_code = INSTRUMENT_ID,
      recording_device_type_code = INSTRUMENT_TYPE,
      recording_duration_secs = RECORDING_DURATION_SECONDS,
      recording_interval_secs = RECORDING_INTERVAL_SECONDS,
      recording_sample_rate_khz = SAMPLING_RATE_HZ / 1000,
      recording_bit_depth = SAMPLE_BITS,
      recording_n_channels = CHANNEL,
      recording_timezone = SOUNDFILES_TIMEZONE,
      recording_device_depth_m = RECORDER_DEPTH_METERS,
      points_of_contact = if_else(
        is.na(DATA_POC_NAME), NA_character_,
        paste0(DATA_POC_NAME, " <", DATA_POC_EMAIL, ">")
      ),
      project_funding = project_funding
    )
}

# optional detectiondata columns that some raw files omit entirely (e.g. the
# localization block, absent when a submission has no localized detections).
# the combined legacy frame hides this because bind_rows unions columns, so a
# per-submission converter must add them as NA
LEGACY_DETECTIONDATA_OPTIONAL <- c(
  "CALL_TYPE_CODE", "N_VALIDATED_DETECTIONS", "DETECTION_METHOD",
  "PROTOCOL_REFERENCE", "DETECTION_SOFTWARE_VERSION",
  "MIN_ANALYSIS_FREQUENCY_RANGE_HZ", "MAX_ANALYSIS_FREQUENCY_RANGE_HZ",
  "ANALYSIS_SAMPLING_RATE_HZ", "QC_PROCESSING",
  "LOCALIZED_LATITUDE", "LOCALIZED_LONGITUDE", "DETECTION_DISTANCE_M"
)

legacy_to_pars_detectiondata <- function (detectiondata, organization_code,
                                          analysis_citations = NA_character_) {
  for (col in setdiff(LEGACY_DETECTIONDATA_OPTIONAL, names(detectiondata))) {
    detectiondata[[col]] <- NA_character_
  }

  detectiondata |>
    mutate(species = SPECIES_CODE) |>
    # the analysis-level fields are grouping keys in PARS, so they must be
    # constant across an analysis. legacy has no analysis record, so each is
    # aggregated over the deployment x species group - the same reduction the
    # legacy pipeline applies (min/max/max)
    group_by(UNIQUE_ID, species) |>
    mutate(
      grp_start = legacy_stamp_utc(min(ANALYSIS_PERIOD_START_DATETIME)),
      grp_end = legacy_stamp_utc(max(ANALYSIS_PERIOD_END_DATETIME)),
      grp_sample_rate = suppressWarnings(max(as.numeric(ANALYSIS_SAMPLING_RATE_HZ), na.rm = TRUE)),
      grp_min_freq = suppressWarnings(min(as.numeric(MIN_ANALYSIS_FREQUENCY_RANGE_HZ), na.rm = TRUE)),
      grp_max_freq = suppressWarnings(max(as.numeric(MAX_ANALYSIS_FREQUENCY_RANGE_HZ), na.rm = TRUE))
    ) |>
    ungroup() |>
    transmute(
      analysis_organization_code = organization_code,
      deployment_code = UNIQUE_ID,
      analysis_sound_source_codes = species,
      analysis_start_datetime = grp_start,
      analysis_end_datetime = grp_end,
      # an empty group reduces to +/-Inf; restore NA so the field is blank
      analysis_sample_rate_khz = if_else(is.finite(grp_sample_rate), grp_sample_rate / 1000, NA_real_),
      analysis_min_frequency_khz = if_else(is.finite(grp_min_freq), grp_min_freq / 1000, NA_real_),
      analysis_max_frequency_khz = if_else(is.finite(grp_max_freq), grp_max_freq / 1000, NA_real_),
      analysis_processing_code = case_when(
        QC_PROCESSING == "ARCHIVAL" ~ "POST_PROCESSED",
        QC_PROCESSING == "REAL-TIME" ~ "REAL_TIME",
        TRUE ~ QC_PROCESSING
      ),
      analysis_protocol_reference = PROTOCOL_REFERENCE,
      analysis_citations = analysis_citations,
      analysis_detector_code = legacy_detector_code(DETECTION_METHOD),
      analysis_detector_version = DETECTION_SOFTWARE_VERSION,
      detection_start_datetime = legacy_stamp_utc(ANALYSIS_PERIOD_START_DATETIME),
      detection_end_datetime = legacy_stamp_utc(ANALYSIS_PERIOD_END_DATETIME),
      detection_effort_secs = as.numeric(ANALYSIS_PERIOD_EFFORT_SECONDS),
      detection_sound_source_code = species,
      detection_call_type_code = legacy_call_type_code(CALL_TYPE_CODE),
      detection_n_validated = as.numeric(N_VALIDATED_DETECTIONS),
      detection_result_code = ACOUSTIC_PRESENCE,
      localization_method_code = NA_character_,
      localization_latitude = as.numeric(LOCALIZED_LATITUDE),
      localization_longitude = as.numeric(LOCALIZED_LONGITUDE),
      localization_distance_m = as.numeric(DETECTION_DISTANCE_M)
    )
}

legacy_to_pars_gpsdata <- function (gpsdata) {
  gpsdata |>
    transmute(
      deployment_code = UNIQUE_ID,
      datetime = legacy_stamp_utc(DATETIME),
      latitude = LATITUDE,
      longitude = LONGITUDE
    )
}

# convert one legacy submission's raw frames into PARS files under dir/clean/.
# `metadata`/`detectiondata`/`gpsdata` are the raw character frames *after* any
# submission-specific fixes; this applies the shared clean_*() + parse_*() chain
# (so timezone and code handling are byte-identical to the legacy loader) then
# the converters above. `gpsdata` is written only when supplied. Called from each
# submission's clean.R with its own organization_code / project_funding
convert_legacy_submission <- function (dir, metadata = NULL, detectiondata = NULL,
                                       gpsdata = NULL, organization_code,
                                       project_funding = NA_character_) {
  # the clean/parse chain expects the all-character shape a clean/*.csv holds,
  # but a submission's clean.R may hand over frames with typed columns (a numeric
  # RECORDING_DURATION_SECONDS, a POSIXct datetime). normalise to character first
  # so parse_* sees the same input whether the frame came from a CSV or in memory
  as_raw <- function (x) mutate(x, across(everything(), as.character))

  clean_dir <- file.path(dir, "clean")
  dir.create(clean_dir, showWarnings = FALSE, recursive = TRUE)

  # metadata and detectiondata are each optional, and legitimately so - global
  # referential integrity (matched on deployment_code across the whole pool) lets
  # a submission carry only one side:
  #   - metadata-only: deploys recorders whose detections another submission
  #     analysed and submitted (DFOCA_20220712, whose baleen detections JASCO holds)
  #   - detections-only: analyses deployments another submission provided (the
  #     DFOCA LF sei-whale submissions, resolving against DFO/JASCO metadata)
  # each writes only its own clean/*.csv; the missing side resolves globally.
  if (!is.null(metadata)) {
    pars_metadata <- metadata |>
      as_raw() |>
      clean_metadata() |>
      parse_metadata() |>
      legacy_to_pars_metadata(organization_code, project_funding)
    write_csv(pars_metadata, file.path(clean_dir, "metadata.csv"), na = "")
  }

  if (!is.null(detectiondata)) {
    pars_detectiondata <- detectiondata |>
      as_raw() |>
      clean_detectiondata() |>
      parse_detectiondata() |>
      legacy_to_pars_detectiondata(organization_code)
    write_csv(
      pars_detectiondata, file.path(clean_dir, "detectiondata.csv"), na = ""
    )
  }

  if (!is.null(gpsdata)) {
    pars_gpsdata <- gpsdata |>
      as_raw() |>
      clean_gpsdata() |>
      parse_gpsdata() |>
      legacy_to_pars_gpsdata()
    write_csv(pars_gpsdata, file.path(clean_dir, "gpsdata.csv"), na = "")
  }

  invisible(clean_dir)
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

