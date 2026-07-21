# comparison harness for PACM output snapshots
#
# used to prove that a refactor or source migration leaves published output
# unchanged: capture a baseline, rebuild, then diff the two

# analyses needs a composite key: a single Makara analysis covers several
# species under one analysis_id, so the id alone does not identify a row
PACM_SNAPSHOT_KEYS <- list(
  sites = "site_id",
  deployments = "deployment_id",
  analyses = c("analysis_id", "species"),
  tracks = "track_id",
  citations = "code"
)

PACM_KEY_SEPARATOR <- " | "

build_key <- function (table, columns, table_name, side) {
  missing <- setdiff(columns, names(table))
  if (length(missing) > 0) {
    stop(
      "key column(s) '", paste(missing, collapse = "', '"),
      "' missing from ", side, " table '", table_name, "'"
    )
  }

  key <- do.call(
    paste,
    c(lapply(columns, function (column) as.character(table[[column]])),
      sep = PACM_KEY_SEPARATOR)
  )

  duplicated_keys <- unique(key[duplicated(key)])
  if (length(duplicated_keys) > 0) {
    stop(
      "key (", paste(columns, collapse = " + "), ") is not unique in ", side,
      " table '", table_name, "': ", length(duplicated_keys),
      " duplicated value(s), e.g. '", duplicated_keys[[1]], "'"
    )
  }

  key
}

PACM_SNAPSHOT_DIFF_COLUMNS <- c(
  "table", "key", "change", "column", "baseline_value", "new_value"
)

empty_diff <- function () {
  x <- replicate(length(PACM_SNAPSHOT_DIFF_COLUMNS), character(0), simplify = FALSE)
  names(x) <- PACM_SNAPSHOT_DIFF_COLUMNS
  tibble::as_tibble(x)
}

# round doubles so float noise below the tolerance does not register as a change
normalize_numeric <- function (x, tolerance) {
  digits <- max(0, ceiling(-log10(tolerance)))
  rec <- function (e) {
    if (inherits(e, "sfg")) {
      # sf wraps the components of a MULTILINESTRING differently depending on
      # how it was built - st_cast() from a LINESTRING leaves the component
      # classed as an sfg, st_combine() leaves it a bare matrix. only the
      # coordinates carry meaning, so strip the wrapper and compare the numbers
      rec(unclass(e))
    } else if (is.data.frame(e)) {
      e[] <- lapply(e, rec)
      e
    } else if (is.list(e)) {
      lapply(e, rec)
    } else if (is.double(e) && is.null(attr(e, "class"))) {
      # classed doubles (POSIXct, Date, units) must not be rounded - round()
      # dispatches on class and rejects a digits argument
      round(e, digits)
    } else {
      e
    }
  }
  rec(x)
}

# list-columns (nested detections, sf geometry) are compared by hash: exact, but
# it reports the column rather than the specific nested field that changed
hash_column <- function (x, tolerance) {
  vapply(x, function (e) rlang::hash(normalize_numeric(e, tolerance)), character(1))
}

values_differ <- function (new_value, baseline_value, tolerance) {
  one_missing <- xor(is.na(new_value), is.na(baseline_value))

  if (is.list(new_value) || is.list(baseline_value)) {
    return(hash_column(new_value, tolerance) != hash_column(baseline_value, tolerance))
  }

  if (is.numeric(new_value) && is.numeric(baseline_value)) {
    differs <- abs(new_value - baseline_value) > tolerance
  } else {
    differs <- as.character(new_value) != as.character(baseline_value)
  }
  differs[is.na(differs)] <- FALSE

  differs | one_missing
}

format_value <- function (x, i) {
  if (is.list(x)) {
    paste0("<", class(x[[i]])[[1]], ">")
  } else {
    as.character(x[[i]])
  }
}

compare_one_table <- function (new_table, baseline_table, table, key, tolerance) {
  if (is.null(new_table) && is.null(baseline_table)) return(empty_diff())

  # a whole table can be absent from one side - towed_pacm carries sites = NULL.
  # report its rows as added or removed and skip column comparison entirely
  new_keys <- if (is.null(new_table)) {
    character(0)
  } else {
    build_key(new_table, key, table, "new")
  }
  baseline_keys <- if (is.null(baseline_table)) {
    character(0)
  } else {
    build_key(baseline_table, key, table, "baseline")
  }
  both_present <- !is.null(new_table) && !is.null(baseline_table)
  new_names <- if (both_present) names(new_table) else character(0)
  baseline_names <- if (both_present) names(baseline_table) else character(0)

  added <- setdiff(new_keys, baseline_keys)
  removed <- setdiff(baseline_keys, new_keys)
  common <- intersect(baseline_keys, new_keys)

  rows <- list(
    tibble::tibble(
      table = table, key = added, change = "added",
      column = NA_character_, baseline_value = NA_character_, new_value = NA_character_
    ),
    tibble::tibble(
      table = table, key = removed, change = "removed",
      column = NA_character_, baseline_value = NA_character_, new_value = NA_character_
    ),
    tibble::tibble(
      table = table, key = NA_character_,
      change = "column_added", column = setdiff(new_names, baseline_names),
      baseline_value = NA_character_, new_value = NA_character_
    ),
    tibble::tibble(
      table = table, key = NA_character_,
      change = "column_removed", column = setdiff(baseline_names, new_names),
      baseline_value = NA_character_, new_value = NA_character_
    )
  )

  if (length(common) > 0) {
    # index columns rather than subsetting the tables: row-subsetting a
    # tibble-backed sf fails unless the sf namespace happens to be loaded
    new_rows <- match(common, new_keys)
    baseline_rows <- match(common, baseline_keys)

    shared_columns <- setdiff(intersect(baseline_names, new_names), key)
    for (column in shared_columns) {
      n <- new_table[[column]][new_rows]
      b <- baseline_table[[column]][baseline_rows]

      differs <- which(values_differ(n, b, tolerance))
      if (length(differs) == 0) next
      rows[[length(rows) + 1]] <- tibble::tibble(
        table = table,
        key = common[differs],
        change = "changed",
        column = column,
        baseline_value = vapply(
          differs, function (i) format_value(b, i), character(1)
        ),
        new_value = vapply(
          differs, function (i) format_value(n, i), character(1)
        )
      )
    }
  }

  dplyr::bind_rows(rows)
}

# snapshots are stored outside the targets store so a rebuild cannot overwrite
# the reference they are being compared against
save_pacm_snapshot <- function (x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(x, path)
  invisible(path)
}

read_pacm_snapshot <- function (path) {
  if (!file.exists(path)) {
    stop(
      "no baseline snapshot at '", path,
      "' - capture one first with save_pacm_snapshot()"
    )
  }
  readRDS(path)
}

PACM_BASELINE_PATH <- "data-raw/baseline/pacm_data.rds"

# capture the reference output the migration is measured against
#
#   capture_pacm_baseline(tar_read(pacm_data))
#
# gitignored (*.rds), so it is a local artifact - recapture after a fresh clone
capture_pacm_baseline <- function (data, path = PACM_BASELINE_PATH) {
  save_pacm_snapshot(data, path)
}

# diff current output against the captured baseline
#
#   compare_to_baseline(tar_read(pacm_data))
#
# an empty result means the pipeline still produces the baseline output
compare_to_baseline <- function (data, path = PACM_BASELINE_PATH, ...) {
  compare_pacm_snapshot(data, read_pacm_snapshot(path), ...)
}

# compare two PACM snapshots, keyed by the stable id of each table
#
# returns one row per difference: added/removed rows, added/removed columns, and
# per-field value changes. an empty result means the snapshots match.
compare_pacm_snapshot <- function (new, baseline, keys = PACM_SNAPSHOT_KEYS, tolerance = 1e-9) {
  tables <- names(keys)[names(keys) %in% union(names(new), names(baseline))]

  diffs <- lapply(tables, function (table) {
    compare_one_table(new[[table]], baseline[[table]], table, keys[[table]], tolerance)
  })

  dplyr::bind_rows(empty_diff(), diffs)
}
