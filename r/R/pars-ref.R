# PARS reference-code vocabulary
#
# submission validation must run without a database connection, so the codes
# come from a vendored snapshot of Makara's reference_codes rather than a live
# query. legacy values that have no official code yet are carried in a
# supplement CSV, and the vocabulary used for validation is the union of the
# two. the supplement is reported at build time so it stays visible instead
# of becoming shadow vocabulary.

PARS_CODES_SNAPSHOT_PATH <- "data-raw/pars/reference_codes_makara.json"
PARS_CODES_SUPPLEMENT_PATH <- "data-raw/pars/reference_codes_supplement.csv"

SUPPLEMENT_COLUMNS <- c("table", "code", "label", "rationale", "date_added")

validate_supplement <- function (supplement) {
  missing <- setdiff(SUPPLEMENT_COLUMNS, names(supplement))
  if (length(missing) > 0) {
    stop(
      "reference code supplement is missing column(s): ",
      paste(missing, collapse = ", ")
    )
  }

  rationale <- supplement$rationale
  blank_rationale <- is.na(rationale) | trimws(rationale) == ""
  if (any(blank_rationale)) {
    stop(
      "every supplement code needs a rationale; missing for: ",
      paste(supplement$code[blank_rationale], collapse = ", ")
    )
  }

  invisible(supplement)
}

# vocabulary used to validate submissions: vendored Makara codes plus supplement
union_reference_codes <- function (snapshot, supplement) {
  validate_supplement(supplement)

  codes <- snapshot$tables
  for (table in unique(supplement$table)) {
    added <- supplement$code[supplement$table == table]
    codes[[table]] <- sort(unique(c(codes[[table]], added)))
  }

  codes
}

# one row per supplement code, flagging any that upstream has since adopted
supplement_code_report <- function (supplement, snapshot) {
  validate_supplement(supplement)

  upstream <- snapshot$tables
  retirable <- mapply(
    function (table, code) code %in% upstream[[table]],
    supplement$table,
    supplement$code,
    USE.NAMES = FALSE
  )

  tibble::tibble(
    table = supplement$table,
    code = supplement$code,
    rationale = supplement$rationale,
    date_added = supplement$date_added,
    retirable = as.logical(retirable)
  )
}

# what changed upstream since the snapshot was captured - reported, never
# applied silently, so a vocabulary change is a decision rather than a surprise
reference_code_drift <- function (upstream, snapshot) {
  vendored <- snapshot$tables
  tables <- union(names(upstream), names(vendored))

  drift <- lapply(tables, function (table) {
    added <- setdiff(upstream[[table]], vendored[[table]])
    removed <- setdiff(vendored[[table]], upstream[[table]])
    tibble::tibble(
      table = table,
      code = c(added, removed),
      change = c(
        rep("added_upstream", length(added)),
        rep("removed_upstream", length(removed))
      )
    )
  })

  dplyr::bind_rows(drift)
}

write_reference_code_snapshot <- function (tables, path, pars_template_version) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    list(
      pars_template_version = pars_template_version,
      source = "makara reference_codes",
      tables = lapply(tables, function (codes) sort(unique(codes)))
    ),
    path,
    auto_unbox = TRUE,
    pretty = TRUE
  )
  invisible(path)
}

read_reference_code_snapshot <- function (path) {
  if (!file.exists(path)) {
    stop(
      "no reference code snapshot at '", path,
      "' - regenerate it from Makara with write_reference_code_snapshot()"
    )
  }
  # simplifyVector keeps each table a character vector, but a length-1 table
  # would otherwise come back as a scalar, so re-wrap defensively
  snapshot <- jsonlite::read_json(path, simplifyVector = TRUE)
  snapshot$tables <- lapply(snapshot$tables, as.character)
  snapshot
}

read_code_supplement <- function (path) {
  if (!file.exists(path)) {
    stop("no reference code supplement at '", path, "'")
  }
  readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character())
  )
}

# regenerate the vendored snapshot from Makara
# run deliberately after reviewing pars_codes_drift, not as part of a build
refresh_reference_code_snapshot <- function (pars_template_version = "1.0") {
  tar_load(makara_codes)
  write_reference_code_snapshot(
    makara_codes,
    PARS_CODES_SNAPSHOT_PATH,
    pars_template_version
  )
}

# targets --------------------------------------------------------------------

targets_pars_ref <- list(
  tar_target(
    pars_codes_snapshot_file, PARS_CODES_SNAPSHOT_PATH, format = "file"
  ),
  tar_target(
    pars_codes_supplement_file, PARS_CODES_SUPPLEMENT_PATH, format = "file"
  ),
  tar_target(
    pars_codes_snapshot,
    read_reference_code_snapshot(pars_codes_snapshot_file)
  ),
  tar_target(
    pars_codes_supplement,
    read_code_supplement(pars_codes_supplement_file)
  ),

  # the vocabulary submissions validate against - no database connection needed
  tar_target(
    pars_codes,
    union_reference_codes(pars_codes_snapshot, pars_codes_supplement)
  ),

  # keep supplement codes visible rather than letting them become shadow vocabulary
  tar_target(pars_codes_report, {
    report <- supplement_code_report(pars_codes_supplement, pars_codes_snapshot)
    if (nrow(report) > 0) {
      log_info("PARS reference codes: {nrow(report)} supplement code(s) in use")
      retirable <- dplyr::filter(report, retirable)
      if (nrow(retirable) > 0) {
        log_warn(
          "{nrow(retirable)} supplement code(s) now exist upstream and can be retired: ",
          "{paste(retirable$code, collapse = ', ')}"
        )
      }
    }
    report
  }),

  # drift is reported, never applied silently; needs the database
  tar_target(pars_codes_drift, {
    drift <- reference_code_drift(makara_codes, pars_codes_snapshot)
    if (nrow(drift) > 0) {
      log_warn(
        "Makara reference codes have drifted from the vendored snapshot ",
        "({nrow(drift)} change(s)); review then run refresh_reference_code_snapshot()"
      )
    }
    drift
  })
)
