# PARS submissions ingest natively: raw/ holds the files exactly as submitted,
# clean.R applies any corrections, and clean/ is what the loader reads (AD-3).
# a conforming submission needs no clean.R at all.

# platform types that require gpsdata. mirrors the `mobile` flag on
# makara_db$platform_types, kept as a constant so submission loading does not
# need a database connection; pars_platform_type_drift guards it going stale
PARS_MOBILE_PLATFORM_TYPES <- c(
  "DRIFTING_BUOY", "ELECTRIC_GLIDER", "TOWED_ARRAY", "WAVE_GLIDER"
)

# the manifest `format` column selects the validation profile (AD-10)
pars_profile_for_format <- function (format) {
  if (format == "PARS_LEGACY") {
    return("PARS_LEGACY")
  }
  if (grepl("^PARS_[0-9]", format)) {
    return("PARS_1.0")
  }
  stop(
    "unsupported PARS submission format: '", format,
    "'; expected PARS_<version> or PARS_LEGACY"
  )
}

# functions --------------------------------------------------------------

# run the `clean.R` script for a given submission ID
clean_pars <- function (submission_id, root_dir = "data-raw/pars") {
  sub_dir <- file.path(root_dir, submission_id)
  clean_script <- file.path(sub_dir, "clean.R")
  if (!file.exists(clean_script)) {
    message(glue("No clean.R for {submission_id}; nothing to run"))
    return(invisible(character(0)))
  }

  source(clean_script, local = new.env(parent = globalenv()))

  clean_files <- list.files(file.path(sub_dir, "clean"), pattern = "\\.csv$")
  invisible(clean_files)
}

# clean multiple submissions
# clean_pars_all(pars_manifest$submission_id)
clean_pars_all <- function (ids) {
  walk(ids, clean_pars)
}

# map parsed PARS metadata onto the published deployment shape
#
# column names and types must match what the other sources emit, or bind_rows
# in pacm_data_raw will coerce or fail: recorder_depth_meters is character and
# sampling_rate_hz is a formatted string ("48,000"), not a number
pars_deployments_table <- function (metadata) {
  metadata |>
    transmute(
      submission_id = if ("submission_id" %in% names(metadata)) submission_id else NA_character_,
      organization_code = deployment_organization_code,
      deployment_id = glue("{deployment_organization_code}:{deployment_code}"),
      deployment_code,
      project = project_name,
      site = site_code,
      latitude = deployment_latitude,
      longitude = deployment_longitude,
      monitoring_start_datetime,
      monitoring_end_datetime,
      platform_type = deployment_platform_type_code,
      deployment_type = if_else(
        deployment_platform_type_code %in% PARS_MOBILE_PLATFORM_TYPES,
        "MOBILE",
        "STATIONARY"
      ),
      water_depth_meters = deployment_water_depth_m,
      recorder_depth_meters = as.character(recording_device_depth_m),
      instrument_type = recording_device_type_code,
      sampling_rate_hz = format_number(recording_sample_rate_khz * 1000),
      data_poc = points_of_contact,
      recording_device_lost = FALSE,
      dynamic_management_platform,
      source = "PARS",

      # new with PARS; carried but not surfaced in the UI yet (AD-7)
      deployment_url,
      project_funding,
      recording_duration_secs,
      recording_interval_secs
    )
}

# PARS only requires detection_sound_source_code when something was detected, so
# a NOT_DETECTED row does not say *which* species was absent. those rows are
# expanded against analysis_sound_source_codes to recover per-species coverage.
# without this, "not detected" days silently disappear for every species except
# the ones that happened to be detected.
pars_expand_species <- function (detectiondata) {
  named <- !is.na(detectiondata$detection_sound_source_code)

  direct <- detectiondata[named, ] |>
    mutate(species = detection_sound_source_code)

  expanded <- detectiondata[!named, ] |>
    mutate(species = strsplit(analysis_sound_source_codes, ",")) |>
    unnest(species) |>
    mutate(species = trimws(species))

  bind_rows(direct, expanded)
}

# fields that identify one analysis. PARS has no analysis_code: rows belong to
# the same analysis when every analysis_* value matches
PARS_ANALYSIS_KEYS <- c(
  "submission_id", "deployment_code", "analysis_organization_code",
  "analysis_sound_source_codes", "analysis_start_datetime",
  "analysis_end_datetime", "analysis_sample_rate_khz",
  "analysis_min_frequency_khz", "analysis_max_frequency_khz",
  "analysis_processing_code", "analysis_protocol_reference",
  "analysis_citations", "analysis_detector_code", "analysis_detector_version"
)

# collapse a day's detection rows to a single presence value
pars_daily_presence <- function (detections) {
  detections |>
    mutate(date = as_date(detection_start_datetime)) |>
    nest(rows = -c(date)) |>
    mutate(
      presence = map_chr(rows, function (rows) {
        result <- rows$detection_result_code
        case_when(
          any(result == "DETECTED") ~ "y",
          any(result == "POSSIBLY_DETECTED") ~ "m",
          any(result == "NOT_DETECTED") ~ "n",
          TRUE ~ "na"
        )
      }),
      locations = map(rows, function (rows) {
        located <- rows |>
          filter(!is.na(localization_latitude) & !is.na(localization_longitude))
        if (nrow(located) == 0) return(NULL)
        located |>
          transmute(
            analysis_period_start_datetime = detection_start_datetime,
            analysis_period_end_datetime = detection_end_datetime,
            latitude = localization_latitude,
            longitude = localization_longitude
          )
      })
    ) |>
    select(-rows) |>
    arrange(date)
}

pars_analyses_table <- function (detectiondata, deployments) {
  keys <- intersect(PARS_ANALYSIS_KEYS, names(detectiondata))

  detectiondata |>
    pars_expand_species() |>
    nest(detections = -all_of(c(keys, "species"))) |>
    left_join(
      deployments |>
        select(
          organization_code, deployment_id, deployment_code,
          recorder_depth_meters, instrument_type, sampling_rate_hz
        ),
      by = "deployment_code"
    ) |>
    mutate(
      analysis_id = glue("{deployment_id}:{species}"),
      detection_method = analysis_detector_code,
      qc_data = analysis_processing_code,
      protocol_reference = analysis_protocol_reference,
      citations = analysis_citations,
      analysis_sampling_rate_hz = analysis_sample_rate_khz * 1000,
      call_type = map_chr(
        detections, ~ str_c(na.omit(unique(.$detection_call_type_code)), collapse = ",")
      ),
      detections = map(detections, pars_daily_presence),
      # the window is the range of days actually analysed, taken from the
      # detection rows. PARS analysis_start/end_datetime describe a half-open
      # interval, so using the end datetime's date directly would add a trailing
      # day that was never analysed - and pacm_data would then gap-fill it into a
      # fabricated "not detected". the explicit fields are used to *validate*
      # these rows instead (see pars_analysis_window_errors)
      analysis_start_date = map(detections, ~ min(.$date)) |> reduce(c),
      analysis_end_date = map(detections, ~ max(.$date)) |> reduce(c),
      n_detections = map_int(detections, nrow)
    )
}

# mint a stable citation code for each distinct submitted citation text,
# namespaced by the analysis organization - mirroring the makara ORG:CODE model
# (makara_citations_pacm), so PARS and makara citations share one reference-table
# shape (code, reference). PARS analysis_citations is free-text prose with no
# reliable delimiter, so each distinct blob becomes one citation rather than
# trying to split prose into individual references. Codes are internal join keys
# (the app shows the reference text, not the code) regenerated each build, so an
# index-based suffix is fine - there is no external consumer to keep stable (AD-8).
pars_citation_codes <- function (analyses) {
  analyses |>
    filter(!is.na(citations)) |>
    distinct(analysis_organization_code, reference = citations) |>
    arrange(analysis_organization_code, reference) |>
    group_by(analysis_organization_code) |>
    mutate(code = paste0(analysis_organization_code, ":PARS_", row_number())) |>
    ungroup()
}

# build mobile-platform tracks from PARS gpsdata using the derivation shared
# with the legacy path (AD-5). gpsdata already arrives in the shape
# derive_tracks() expects, so only the extra submission columns are dropped.
pars_tracks_table <- function (gpsdata, deployments) {
  if (is.null(gpsdata) || nrow(gpsdata) == 0) {
    return(NULL)
  }

  positions <- gpsdata |>
    select(deployment_code, datetime, latitude, longitude)

  derive_tracks(positions, deployments)
}

error_frame <- function (row, name, expression, actual) {
  tibble(
    row = row,
    name = name,
    value = FALSE,
    expression = expression,
    actual = actual
  )
}

# every deployment_code referenced by detectiondata or gpsdata must exist in
# metadata, and metadata must not name the same deployment twice
# within-submission check: a submission must not define the same deployment
# twice. this is genuinely local (a self-contained property of one file), so it
# stays per-submission in load_pars
pars_metadata_errors <- function (metadata) {
  if (is.null(metadata)) {
    return(error_frame(integer(0), character(0), character(0), character(0)))
  }

  known <- metadata$deployment_code
  duplicated_codes <- unique(known[duplicated(known)])
  if (length(duplicated_codes) == 0) {
    return(error_frame(integer(0), character(0), character(0), character(0)))
  }

  error_frame(
    row = metadata$row[known %in% duplicated_codes],
    name = "deployment_code_unique",
    expression = "deployment_code is unique within metadata",
    actual = known[known %in% duplicated_codes]
  )
}

# orphan check: every detection/gps deployment_code must exist in metadata.
# this is GLOBAL, not per-submission (Decision 15) - a detection may analyse a
# deployment another submission deployed (JASCO analysed DFO's recorders), so
# `metadata` here is the combined pool, not one submission's file
pars_referential_errors <- function (metadata, detectiondata, gpsdata) {
  if (is.null(metadata)) {
    return(error_frame(integer(0), character(0), character(0), character(0)))
  }

  known <- metadata$deployment_code
  errors <- list()

  for (child in c("detectiondata", "gpsdata")) {
    x <- if (child == "detectiondata") detectiondata else gpsdata
    if (is.null(x)) next
    orphan <- !x$deployment_code %in% known
    if (any(orphan)) {
      errors[[length(errors) + 1]] <- error_frame(
        row = x$row[orphan],
        name = paste0(child, "_deployment_code_known"),
        expression = paste0(child, " deployment_code exists in metadata"),
        actual = x$deployment_code[orphan]
      )
    }
  }

  bind_rows(errors)
}

# mobile platforms must submit gpsdata; stationary ones must not
pars_gpsdata_errors <- function (metadata, gpsdata) {
  if (is.null(metadata)) return(error_frame(integer(0), character(0), character(0), character(0)))

  mobile <- metadata$deployment_platform_type_code %in% PARS_MOBILE_PLATFORM_TYPES
  has_positions <- metadata$deployment_code %in% (gpsdata$deployment_code %||% character(0))

  missing_positions <- mobile & !has_positions
  unexpected_positions <- !mobile & has_positions

  bind_rows(
    error_frame(
      row = metadata$row[missing_positions],
      name = "gpsdata_required_for_mobile",
      expression = "mobile deployments have gpsdata",
      actual = metadata$deployment_code[missing_positions]
    ),
    error_frame(
      row = metadata$row[unexpected_positions],
      name = "gpsdata_unexpected_for_stationary",
      expression = "stationary deployments have no gpsdata",
      actual = metadata$deployment_code[unexpected_positions]
    )
  )
}

load_pars_file <- function (filepath, table, codes, profile, parse) {
  if (!file.exists(filepath)) {
    return(NULL)
  }

  raw <- read_raw_file(filepath)
  parsed <- parse(raw)

  placeholders <- pars_placeholder_errors(raw)
  placeholder_errors <- error_frame(
    row = placeholders$row,
    name = paste0(placeholders$column, "_placeholder"),
    expression = "no NA/NULL/- placeholders",
    actual = placeholders$actual
  )

  errors <- bind_rows(
    placeholder_errors,
    validate_pars(parsed, table, codes, profile)
  )

  # counted before the tibble: inside tibble(), `nrow(errors)` would resolve to
  # the list-column named `errors` being created alongside it, and nrow() of a
  # list is NULL, so the column would be dropped without a word
  n_errors <- nrow(errors)

  tibble(
    filepath = filepath,
    n_rows = nrow(raw),
    raw = list(raw),
    parsed = list(parsed),
    valid = n_errors == 0,
    errors = list(errors),
    n_errors = n_errors
  )
}

load_pars <- function (id, format, skip, root_dir, codes) {
  if (!is.na(skip)) {
    warning(glue("Skipping submission {id} with format {format}"))
    return(NULL)
  }

  profile <- pars_profile_for_format(format)

  # where the loader reads from (AD-3):
  #   - clean/ once clean.R has produced it - the corrected files
  #   - raw/ directly when the submission is CONFORMING: no corrections, so no
  #     clean.R and no clean/. a conforming submission needs no clean.R at all.
  #   - but a submission that HAS a clean.R whose clean/ was never generated is a
  #     mistake, not a conforming one: reading raw/ would silently ingest the
  #     very values clean.R exists to fix (the USYRA sample-rate error), so that
  #     case stops and tells you to run clean_pars().
  clean_dir <- file.path(root_dir, id, "clean")
  raw_dir <- file.path(root_dir, id, "raw")
  has_clean_script <- file.exists(file.path(root_dir, id, "clean.R"))

  data_dir <- if (dir.exists(clean_dir)) {
    clean_dir
  } else if (has_clean_script) {
    stop(glue(
      "PARS submission {id} has a clean.R but no clean/ directory. ",
      "Run clean_pars('{id}') to generate it."
    ))
  } else if (dir.exists(raw_dir)) {
    raw_dir
  } else {
    stop(glue(
      "No data directory for PARS submission {id} ",
      "(expected {clean_dir} or {raw_dir})."
    ))
  }

  metadata <- load_pars_file(
    file.path(data_dir, "metadata.csv"), "metadata", codes, profile,
    parse_pars_metadata
  )
  detectiondata <- load_pars_file(
    file.path(data_dir, "detectiondata.csv"), "detectiondata", codes, profile,
    parse_pars_detectiondata
  )
  gpsdata <- load_pars_file(
    file.path(data_dir, "gpsdata.csv"), "gpsdata", codes, profile,
    parse_pars_gpsdata
  )

  # only within-submission checks live on the submission. referential integrity
  # (detection/gps orphans, mobile<->gps) is GLOBAL, over the combined pool
  # (Decision 15) - a submission may analyse a deployment another submission
  # provided - so it runs in the pipeline (`pars_referential`), not here
  errors <- pars_metadata_errors(metadata$parsed[[1]])

  # a tibble rather than a list: tar_combine binds these with bind_rows(), and
  # a bare list of list-columns is not unambiguously coercible to a row
  tibble(
    id = id,
    metadata = list(metadata),
    detectiondata = list(detectiondata),
    gpsdata = list(gpsdata),
    errors = list(errors)
  )
}

