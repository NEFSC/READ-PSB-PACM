# PARS submission validation
#
# two profiles (AD-10): `PARS_1.0` validates new submissions strictly;
# `PARS_LEGACY` applies to submissions converted from the legacy format and
# relaxes exactly two things - the presence of fields legacy never collected,
# and the cardinality of detection_call_type_code. it must never relax a check
# that catches corruption (type, range, vocabulary, referential integrity),
# because those are what caught the USYRA sample-rate error (I-1).
#
# checks are split by kind: `validate` handles presence, ranges, and
# comparisons, while vocabulary membership is checked in plain R. that split is
# not stylistic - validate's expression language rejects the function call
# needed to validate a comma-separated list of codes.

PARS_PROFILES <- c("PARS_1.0", "PARS_LEGACY")

# fields legacy never collected; presence is relaxed under PARS_LEGACY only
PARS_LEGACY_OPTIONAL <- c("project_funding", "analysis_detector_version")

# a sample rate outside this band is a unit error, not a real configuration.
# 48000 (Hz submitted in a kHz field) is the case this exists to catch
PARS_SAMPLE_RATE_KHZ_RANGE <- c(0.1, 2000)

PARS_REQUIRED <- list(
  metadata = c(
    "deployment_organization_code", "deployment_code", "project_name",
    "site_code", "monitoring_start_datetime", "monitoring_end_datetime",
    "deployment_latitude", "deployment_longitude",
    "deployment_platform_type_code", "deployment_water_depth_m",
    "recording_device_depth_m", "recording_device_code",
    "recording_device_type_code", "recording_duration_secs",
    "recording_interval_secs", "recording_sample_rate_khz",
    "recording_bit_depth", "recording_n_channels", "recording_timezone",
    "points_of_contact", "project_funding"
  ),
  detectiondata = c(
    "deployment_code", "analysis_organization_code",
    "analysis_sound_source_codes", "analysis_start_datetime",
    "analysis_end_datetime", "analysis_sample_rate_khz",
    "analysis_min_frequency_khz", "analysis_max_frequency_khz",
    "analysis_processing_code", "analysis_protocol_reference",
    "analysis_detector_code", "analysis_detector_version",
    "detection_start_datetime", "detection_end_datetime",
    "detection_effort_secs", "detection_result_code"
  ),
  gpsdata = c("deployment_code", "datetime", "latitude", "longitude")
)

# column -> reference table. detection_call_type_code accepts a comma-separated
# list under PARS_LEGACY (AD-10); every element is still validated
PARS_VOCABULARY <- list(
  metadata = list(
    deployment_organization_code = "organizations",
    deployment_platform_type_code = "platform_types",
    recording_device_type_code = "device_types"
  ),
  detectiondata = list(
    analysis_organization_code = "organizations",
    analysis_sound_source_codes = "sound_sources",
    analysis_processing_code = "analysis_processing_types",
    analysis_detector_code = "detectors",
    detection_sound_source_code = "sound_sources",
    detection_call_type_code = "call_types",
    detection_result_code = "detection_result_types"
  ),
  gpsdata = list()
)

# columns whose value may be a comma-separated list of codes, by profile
pars_list_valued <- function (profile) {
  listed <- "analysis_sound_source_codes"
  if (profile == "PARS_LEGACY") {
    listed <- c(listed, "detection_call_type_code")
  }
  listed
}

PARS_RANGE_RULES <- list(
  metadata = c(
    deployment_latitude_range = "deployment_latitude >= -90 & deployment_latitude <= 90",
    deployment_longitude_range = "deployment_longitude >= -180 & deployment_longitude <= 180",
    deployment_water_depth_m_range = "deployment_water_depth_m >= 0",
    recording_device_depth_m_range = "recording_device_depth_m >= 0",
    recording_duration_secs_range = "recording_duration_secs >= 0",
    recording_interval_secs_range = "recording_interval_secs >= 0",
    recording_bit_depth_range = "recording_bit_depth >= 0",
    recording_n_channels_range = "recording_n_channels >= 0",
    recording_sample_rate_khz_range = "recording_sample_rate_khz >= 0.1 & recording_sample_rate_khz <= 2000",
    monitoring_period_ordered = "monitoring_start_datetime <= monitoring_end_datetime"
  ),
  detectiondata = c(
    analysis_sample_rate_khz_range = "analysis_sample_rate_khz >= 0.1 & analysis_sample_rate_khz <= 2000",
    analysis_min_frequency_khz_range = "analysis_min_frequency_khz >= 0",
    analysis_max_frequency_khz_range = "analysis_max_frequency_khz >= 0",
    analysis_frequency_ordered = "analysis_min_frequency_khz <= analysis_max_frequency_khz",
    detection_effort_secs_range = "detection_effort_secs >= 0",
    detection_n_validated_range = "detection_n_validated >= 0",
    localization_latitude_range = "localization_latitude >= -90 & localization_latitude <= 90",
    localization_longitude_range = "localization_longitude >= -180 & localization_longitude <= 180",
    localization_distance_m_range = "localization_distance_m >= 0",
    analysis_period_ordered = "analysis_start_datetime <= analysis_end_datetime",
    detection_period_ordered = "detection_start_datetime <= detection_end_datetime",
    # the analysis window bounds its detections; PARS treats it as half-open,
    # so a detection may start at the window start but must end by its end
    detection_within_analysis_start = "detection_start_datetime >= analysis_start_datetime",
    detection_within_analysis_end = "detection_end_datetime <= analysis_end_datetime"
  ),
  gpsdata = c(
    latitude_range = "latitude >= -90 & latitude <= 90",
    longitude_range = "longitude >= -180 & longitude <= 180"
  )
)

# fields required only when the row reports a detection
PARS_CONDITIONAL_RULES <- c(
  detection_sound_source_code_required = paste(
    "!(detection_result_code %in% c('DETECTED', 'POSSIBLY_DETECTED'))",
    "| !is.na(detection_sound_source_code)"
  ),
  detection_call_type_code_required = paste(
    "!(detection_result_code %in% c('DETECTED', 'POSSIBLY_DETECTED'))",
    "| !is.na(detection_call_type_code)"
  ),
  detection_n_validated_required = paste(
    "!(detection_result_code %in% c('DETECTED', 'POSSIBLY_DETECTED'))",
    "| !is.na(detection_n_validated)"
  )
)

check_profile <- function (profile) {
  if (!profile %in% PARS_PROFILES) {
    stop(
      "unknown validation profile '", profile, "'; expected one of: ",
      paste(PARS_PROFILES, collapse = ", ")
    )
  }
}

pars_required_columns <- function (table, profile) {
  required <- PARS_REQUIRED[[table]]
  if (profile == "PARS_LEGACY") {
    required <- setdiff(required, PARS_LEGACY_OPTIONAL)
  }
  required
}

# required columns the submitted file omits entirely. reported separately
# because a rule referencing an absent column cannot be evaluated at all
pars_missing_columns <- function (x, table, profile = "PARS_1.0") {
  setdiff(pars_required_columns(table, profile), names(x))
}

# presence, range and comparison rules, as a `validate` validator
#
# `columns` restricts the result to rules that can actually be evaluated.
# without it `validate` drops unevaluable rules with only a warning, which
# leaves checks silently not running - a validator that appears to pass because
# it never ran is worse than no validator at all
pars_rules <- function (table, profile = "PARS_1.0", columns = NULL) {
  check_profile(profile)

  required <- pars_required_columns(table, profile)
  presence <- setNames(
    paste0("!is.na(", required, ")"),
    paste0(required, "_present")
  )

  expressions <- c(presence, PARS_RANGE_RULES[[table]])
  if (table == "detectiondata") {
    expressions <- c(expressions, PARS_CONDITIONAL_RULES)
  }

  if (!is.null(columns)) {
    evaluable <- vapply(expressions, function (expression) {
      all(all.vars(str2lang(expression)) %in% columns)
    }, logical(1))
    expressions <- expressions[evaluable]
  }

  if (length(expressions) == 0) {
    return(NULL)
  }

  rules <- do.call(validator, lapply(expressions, str2lang))
  names(rules) <- names(expressions)
  rules
}

# vocabulary membership, checked outside `validate` so that list-valued columns
# can be split and each element checked
pars_vocabulary_errors <- function (x, table, codes, profile = "PARS_1.0") {
  check_profile(profile)

  vocabulary <- PARS_VOCABULARY[[table]]
  columns <- intersect(names(vocabulary), names(x))
  listed <- pars_list_valued(profile)

  errors <- lapply(columns, function (column) {
    allowed <- codes[[vocabulary[[column]]]]
    # not named `value`: tibble() below defines a column of that name and would
    # shadow it
    submitted <- as.character(x[[column]])

    ok <- vapply(seq_along(submitted), function (i) {
      if (is.na(submitted[[i]])) return(TRUE)
      parts <- if (column %in% listed) {
        trimws(strsplit(submitted[[i]], ",")[[1]])
      } else {
        submitted[[i]]
      }
      all(parts %in% allowed)
    }, logical(1))

    tibble::tibble(
      row = x$row[!ok],
      name = paste0(column, "_valid"),
      value = FALSE,
      expression = paste0(column, " in ", vocabulary[[column]]),
      actual = submitted[!ok]
    )
  })

  dplyr::bind_rows(errors)
}

# all validation errors for one PARS table, as one row per failing check
validate_pars <- function (x, table, codes, profile = "PARS_1.0") {
  check_profile(profile)

  missing <- pars_missing_columns(x, table, profile)
  # guarded: paste0(character(0), "_present") yields "_present", not character(0)
  missing_errors <- if (length(missing) == 0) {
    NULL
  } else {
    tibble::tibble(
      row = NA_integer_,
      name = paste0(missing, "_present"),
      value = FALSE,
      expression = paste0("column '", missing, "' present in file"),
      actual = NA_character_
    )
  }

  rules <- pars_rules(table, profile, columns = names(x))
  rule_errors <- if (is.null(rules)) {
    NULL
  } else {
    extract_validation_errors(validate_data(x, rules, codes), x)
  }

  dplyr::bind_rows(
    missing_errors,
    rule_errors,
    pars_vocabulary_errors(x, table, codes, profile)
  )
}
