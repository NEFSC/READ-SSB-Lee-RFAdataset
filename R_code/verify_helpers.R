# ==============================================================================
# verify_helpers.R
# Reusable comparison functions for port verification.
# Repository: READ-SSB-Lee-RFAdataset
#
# Source this file from verify_port.R — do not run standalone.
# Each function returns list(passed, details, ...) so results can be
# aggregated and written to the markdown report.
#
# Required packages: glue, haven, fs, dplyr, tidyr, waldo
# ==============================================================================


# ------------------------------------------------------------------------------
# check_file_exists
# Verifies a file is present before any read attempt.
# ------------------------------------------------------------------------------
check_file_exists <- function(path, label) {
  if (fs::file_exists(path)) {
    list(passed = TRUE,  details = glue::glue("{label}: found at {path}"))
  } else {
    list(passed = FALSE, details = glue::glue("MISSING — {label}: expected at {path}"))
  }
}

# ------------------------------------------------------------------------------
# check_dimensions
# Compares row and column counts. Both must match exactly.
# NOTE: Row order is not checked here — order-insensitive comparison is in check_values().
# ------------------------------------------------------------------------------
check_dimensions <- function(df_stata, df_r, label) {
  sr <- nrow(df_stata); sc <- ncol(df_stata)
  rr <- nrow(df_r);     rc <- ncol(df_r)

  row_ok <- sr == rr
  col_ok <- sc == rc

  details <- c(
    glue::glue("Stata: {sr} rows × {sc} cols"),
    glue::glue("R:     {rr} rows × {rc} cols"),
    if (!row_ok) glue::glue("ROW COUNT MISMATCH: Stata={sr}, R={rr}"),
    if (!col_ok) glue::glue("COL COUNT MISMATCH: Stata={sc}, R={rc}")
  )
  list(passed = row_ok && col_ok, details = details)
}

# ------------------------------------------------------------------------------
# check_column_names
# Compares column name sets (case-normalized to lowercase).
# NOTE: haven::read_dta() always returns lowercase Stata names.
#       R tidyverse pipelines may differ in case — normalize before comparing.
# ------------------------------------------------------------------------------
check_column_names <- function(df_stata, df_r, label) {
  sn <- tolower(names(df_stata))
  rn <- tolower(names(df_r))

  only_stata <- setdiff(sn, rn)
  only_r     <- setdiff(rn, sn)
  passed     <- length(only_stata) == 0 && length(only_r) == 0

  waldo_out <- character(0)
  if (!passed) {
    waldo_out <- tryCatch(
      capture.output(waldo::compare(sort(sn), sort(rn), x_arg = "stata", y_arg = "r")),
      error = function(e) character(0)
    )
  }

  details <- c(
    glue::glue("Stata columns: {length(sn)} | R columns: {length(rn)}"),
    if (length(only_stata) > 0)
      glue::glue("In Stata NOT in R ({length(only_stata)}): {paste(head(only_stata, 20), collapse=', ')}"),
    if (length(only_r) > 0)
      glue::glue("In R NOT in Stata ({length(only_r)}): {paste(head(only_r, 20), collapse=', ')}"),
    if (length(waldo_out) > 0) waldo_out,
    if (passed) "Column names match (case-normalized)"
  )
  list(passed = passed, details = details, only_stata = only_stata, only_r = only_r)
}

# ------------------------------------------------------------------------------
# check_column_types
# For each column present in both frames, compares R class/type.
#
# Type equivalence (WARNING, not FAILURE):
#   haven_labelled/double → numeric, integer, double   (expected after zap_labels)
#
# FAILURES:
#   numeric in Stata → character in R (or vice versa)
#   date type lost
#
# NOTE: Strip haven_labelled attributes before type comparison using haven::zap_labels()
#       to avoid false positives from label metadata differences.
# ------------------------------------------------------------------------------
check_column_types <- function(df_stata, df_r, label) {
  stata_raw   <- df_stata          # keep for class inspection
  stata_clean <- haven::zap_labels(df_stata)

  sn_lower <- tolower(names(stata_clean))
  rn_lower <- tolower(names(df_r))
  common   <- intersect(sn_lower, rn_lower)

  failures <- character(0)
  warns    <- character(0)

  for (col in common) {
    sc_name <- names(stata_clean)[match(col, sn_lower)]
    rc_name <- names(df_r)[match(col, rn_lower)]

    s_raw_cls <- class(stata_raw[[sc_name]])[1]
    s_cls     <- class(stata_clean[[sc_name]])[1]
    r_cls     <- class(df_r[[rc_name]])[1]

    s_num  <- s_cls %in% c("numeric", "integer", "double")
    r_num  <- r_cls %in% c("numeric", "integer", "double")
    s_char <- s_cls == "character"
    r_char <- r_cls == "character"
    s_date <- s_cls %in% c("Date", "POSIXct", "POSIXlt")
    r_date <- r_cls %in% c("Date", "POSIXct", "POSIXlt")

    if (s_num && r_num) {
      if (s_raw_cls == "haven_labelled")
        warns <- c(warns, glue::glue("  {col}: haven_labelled → {r_cls} [expected after zap_labels]"))
    } else if (s_char && r_char) {
      # pass
    } else if (s_date && r_date) {
      # pass
    } else if (s_num && r_char) {
      failures <- c(failures, glue::glue("  {col}: NUMERIC (Stata) → CHARACTER (R)"))
    } else if (s_char && r_num) {
      failures <- c(failures, glue::glue("  {col}: CHARACTER (Stata) → NUMERIC (R)"))
    } else if (s_date && !r_date) {
      failures <- c(failures, glue::glue("  {col}: DATE (Stata) → {r_cls} (R) [date type lost]"))
    } else {
      warns <- c(warns, glue::glue("  {col}: Stata={s_cls}, R={r_cls} [review]"))
    }
  }

  passed  <- length(failures) == 0
  details <- c(
    glue::glue("Checked {length(common)} common columns"),
    if (length(failures) > 0) c("FAILURES:", failures),
    if (length(warns)    > 0) c("WARNINGS:", warns),
    if (passed && length(warns) == 0) "All column types compatible"
  )
  list(passed = passed, details = details, warnings = warns, failures = failures)
}

# ------------------------------------------------------------------------------
# check_missing_values
# Compares NA counts per column.
# NOTE: Stata extended missing values (.a, .b, etc.) become NA in R via haven.
#       Differences here may reflect that; check conversion-notes.md REVIEW items.
# ------------------------------------------------------------------------------
check_missing_values <- function(df_stata, df_r, label) {
  stata_clean <- haven::zap_labels(df_stata)
  sn_lower    <- tolower(names(stata_clean))
  rn_lower    <- tolower(names(df_r))
  common      <- intersect(sn_lower, rn_lower)

  failures <- character(0)

  for (col in common) {
    sc_name <- names(stata_clean)[match(col, sn_lower)]
    rc_name <- names(df_r)[match(col, rn_lower)]

    na_s <- sum(is.na(stata_clean[[sc_name]]))
    na_r <- sum(is.na(df_r[[rc_name]]))

    if (na_s != na_r) {
      failures <- c(failures,
        glue::glue("  {col}: Stata NAs={na_s}, R NAs={na_r}, diff={na_r - na_s}"))
    }
  }

  passed  <- length(failures) == 0
  details <- c(
    glue::glue("Checked {length(common)} common columns for NA counts"),
    if (length(failures) > 0) c("NA MISMATCHES:", failures),
    if (passed) "NA counts match in all common columns"
  )
  list(passed = passed, details = details)
}

# ------------------------------------------------------------------------------
# check_factor_levels
# For any haven_labelled or factor column in the Stata frame: compare unique value sets.
# ------------------------------------------------------------------------------
check_factor_levels <- function(df_stata, df_r, label) {
  labelled_cols <- names(df_stata)[
    vapply(df_stata, function(x) inherits(x, "haven_labelled") || is.factor(x), logical(1))
  ]

  if (length(labelled_cols) == 0)
    return(list(passed = TRUE, details = "No factor/haven_labelled columns in Stata frame"))

  sn_lower <- tolower(names(df_stata))
  rn_lower <- tolower(names(df_r))
  failures <- character(0)

  for (col in labelled_cols) {
    col_lower  <- tolower(col)
    rc_name    <- names(df_r)[match(col_lower, rn_lower)]
    if (is.na(rc_name)) next

    s_vals <- sort(unique(na.omit(as.vector(df_stata[[col]]))))
    r_vals <- sort(unique(na.omit(as.vector(df_r[[rc_name]]))))

    if (!identical(s_vals, r_vals)) {
      only_s <- setdiff(s_vals, r_vals)
      only_r <- setdiff(r_vals, s_vals)
      failures <- c(failures,
        glue::glue("  {col}: value sets differ"),
        if (length(only_s) > 0)
          glue::glue("    In Stata not R: {paste(head(only_s, 10), collapse=',')}"),
        if (length(only_r) > 0)
          glue::glue("    In R not Stata: {paste(head(only_r, 10), collapse=',')}")
      )
    }
  }

  passed  <- length(failures) == 0
  details <- c(
    glue::glue("Checked {length(labelled_cols)} factor/labelled columns"),
    if (length(failures) > 0) failures,
    if (passed) "Factor/labelled level sets match"
  )
  list(passed = passed, details = details)
}

# ------------------------------------------------------------------------------
# check_values
# Core value comparison. Sorts both frames by permit,year before comparing.
#
# NOTE: Row ordering between Stata and R may differ — both are sorted by (permit, year)
#       for element-wise comparison. If no permit/year key exists, sort by all columns
#       and flag this in the report.
#
# NOTE: affiliate_id is excluded from exact value comparison by default.
#       Values are arbitrary sequential integers that change on every pipeline run
#       (documented in phase1-report.md, phase2-master-doc.md, conversion-notes.md,
#       and output_data_description.md Warning 3). Structural equivalence of
#       groupings is checked in check_affiliate_structure() instead.
#
# Numeric: element-wise abs diff vs tolerance (get_tolerance() per column).
# Character: exact match, first 10 mismatches reported.
# NA positions: must match exactly.
# ------------------------------------------------------------------------------
check_values <- function(df_stata, df_r, label,
                         skip_cols = c("affiliate_id")) {
  stata_clean <- haven::zap_labels(df_stata) |> dplyr::rename_with(tolower)
  r_clean     <- df_r |> dplyr::rename_with(tolower)

  # Determine sort key
  sort_key <- intersect(c("permit", "year"), names(stata_clean))
  if (length(sort_key) >= 1) {
    stata_sorted <- stata_clean |> dplyr::arrange(dplyr::across(dplyr::any_of(sort_key)))
    r_sorted     <- r_clean     |> dplyr::arrange(dplyr::across(dplyr::any_of(sort_key)))
    key_note     <- glue::glue("Sorted by: {paste(sort_key, collapse=', ')}")
  } else {
    # NOTE: No permit/year key — sorting by all columns; potentially unstable if ties exist
    stata_sorted <- stata_clean |> dplyr::arrange(dplyr::across(dplyr::everything()))
    r_sorted     <- r_clean     |> dplyr::arrange(dplyr::across(dplyr::everything()))
    key_note     <- "WARNING: No permit/year key found — sorted by all columns (unstable if ties)"
  }

  # Guard: cannot compare if row counts differ
  if (nrow(stata_sorted) != nrow(r_sorted)) {
    return(list(
      passed        = FALSE,
      details       = c(key_note,
                        glue::glue("SKIPPED: row counts differ (Stata={nrow(stata_sorted)}, R={nrow(r_sorted)})")),
      worst_rows    = list(),
      num_failures  = "row count mismatch",
      char_failures = character(0),
      na_failures   = character(0)
    ))
  }


  # Verify (permit, year) keys are aligned (if key available)
  if (all(c("permit", "year") %in% names(stata_sorted))) {
    # Diagnostic: surface type differences that would cause identical() to false-fail
    cat("  [key check] permit class — Stata:", class(stata_sorted$permit),
        "| R:", class(r_sorted$permit), "\n")
    cat("  [key check] year class   — Stata:", class(stata_sorted$year),
        "| R:", class(r_sorted$year), "\n")

    # NOTE: Use all.equal() on coerced doubles rather than identical() — identical()
    # fails on type/attribute differences (e.g. double vs integer, haven attributes)
    # even when the numeric values are the same.
    permit_ok  <- isTRUE(all.equal(as.double(stata_sorted$permit),
                                   as.double(r_sorted$permit)))
    year_ok    <- isTRUE(all.equal(as.double(stata_sorted$year),
                                   as.double(r_sorted$year)))
    # NA positions must also align
    permit_na_ok <- identical(is.na(stata_sorted$permit), is.na(r_sorted$permit))
    year_na_ok   <- identical(is.na(stata_sorted$year),   is.na(r_sorted$year))

    keys_match <- permit_ok && year_ok && permit_na_ok && year_na_ok

    if (!keys_match) {
      diag <- c(
        if (!permit_ok)    "  permit values differ after sorting",
        if (!permit_na_ok) "  permit NA positions differ",
        if (!year_ok)      "  year values differ after sorting",
        if (!year_na_ok)   "  year NA positions differ"
      )
      return(list(
        passed        = FALSE,
        details       = c(key_note,
                          "SKIPPED: (permit, year) key sets do not match after sorting — rows cannot be aligned",
                          diag),
        worst_rows    = list(),
        num_failures  = "(permit,year) key mismatch",
        char_failures = character(0),
        na_failures   = character(0)
      ))
    }
  }
  skip_lower <- tolower(skip_cols)
  common_cols <- setdiff(
    intersect(names(stata_sorted), names(r_sorted)),
    skip_lower
  )

  num_failures  <- character(0)
  char_failures <- character(0)
  na_failures   <- character(0)
  worst_rows    <- list()

  for (col in common_cols) {
    s_vec <- stata_sorted[[col]]
    r_vec <- r_sorted[[col]]

    # NA position check (must match regardless of tolerance)
    s_na <- is.na(s_vec)
    r_na <- is.na(r_vec)
    n_na_mismatch <- sum(s_na != r_na)
    if (n_na_mismatch > 0) {
      na_failures <- c(na_failures,
        glue::glue("  {col}: {n_na_mismatch} rows have NA in one dataset but not the other"))
    }

    both_ok <- !s_na & !r_na
    if (sum(both_ok) == 0) next

    if (is.numeric(s_vec)) {
      tol      <- get_tolerance(col)
      abs_diff <- abs(as.double(s_vec[both_ok]) - as.double(r_vec[both_ok]))
      max_diff <- max(abs_diff, na.rm = TRUE)
      n_exceed <- sum(abs_diff > tol, na.rm = TRUE)

      if (max_diff > tol) {
        num_failures <- c(num_failures,
          glue::glue("  {col}: max_diff={signif(max_diff, 6)}, rows_exceeding_tol={n_exceed}, tol={tol}"))

        # Collect worst rows (up to 20, capped at 5 cols per pair in report)
        worst_idx <- order(abs_diff, decreasing = TRUE)[seq_len(min(20, length(abs_diff)))]
        key_frame <- stata_sorted[both_ok, ][worst_idx, , drop = FALSE] |>
          dplyr::select(dplyr::any_of(c("permit", "year", "affiliate_id")))
        worst_rows[[col]] <- data.frame(
          column   = col,
          key_frame,
          stata_val = as.double(s_vec[both_ok])[worst_idx],
          r_val     = as.double(r_vec[both_ok])[worst_idx],
          abs_diff  = abs_diff[worst_idx]
        )
      }
    } else {
      # Character / factor / other — coerce to character for comparison
      s_char <- as.character(s_vec[both_ok])
      r_char <- as.character(r_vec[both_ok])
      mismatch_idx <- which(s_char != r_char)

      if (length(mismatch_idx) > 0) {
        first <- mismatch_idx[1]
        char_failures <- c(char_failures,
          glue::glue("  {col}: {length(mismatch_idx)} mismatches (first: Stata='{s_char[first]}', R='{r_char[first]}')")
        )
      }
    }
  }

  all_failures <- c(num_failures, char_failures, na_failures)
  passed       <- length(all_failures) == 0

  details <- c(
    key_note,
    glue::glue("Checked {length(common_cols)} common columns (skipped: {paste(skip_lower, collapse=', ')})"),
    glue::glue("NOTE: affiliate_id excluded — values are arbitrary sequential integers (documented)"),
    if (length(all_failures) > 0) c("FAILURES:", all_failures),
    if (passed) "All non-skipped values match within tolerance"
  )
  list(
    passed        = passed,
    details       = details,
    worst_rows    = worst_rows,
    num_failures  = num_failures,
    char_failures = char_failures,
    na_failures   = na_failures
  )
}

# ------------------------------------------------------------------------------
# check_affiliate_structure
# Structural equivalence check for affiliate_id.
# The absolute integer values differ every run (documented). This function
# checks that the PARTITION of permits into affiliate groups is equivalent:
# for any two permits that share an affiliate_id in Stata, they must also
# share an affiliate_id in R (up to relabeling of the integer IDs).
#
# Method: for each dataset, collect the sorted permit-set for each affiliate_id,
# sort the collection of permit-sets, and compare. If the sorted permit-set
# collections are identical, the partitions are equivalent.
#
# NOTE: Only meaningful for the final affiliates file (permit-affiliate key).
#       Uses the full panel (all years) to build the partition.
# ------------------------------------------------------------------------------
check_affiliate_structure <- function(df_stata, df_r, label) {
  stata_clean <- haven::zap_labels(df_stata) |> dplyr::rename_with(tolower)
  r_clean     <- df_r |> dplyr::rename_with(tolower)

  if (!all(c("affiliate_id", "permit") %in% names(stata_clean)) ||
      !all(c("affiliate_id", "permit") %in% names(r_clean))) {
    return(list(
      passed  = TRUE,
      details = "affiliate_id or permit not present — structural check skipped"
    ))
  }

  # Build permit-set signature for each affiliate in each dataset
  canon <- function(df) {
    df |>
      dplyr::select(affiliate_id, permit) |>
      dplyr::distinct() |>
      dplyr::group_by(affiliate_id) |>
      dplyr::summarise(
        permit_set = paste(sort(as.integer(permit)), collapse = "|"),
        .groups    = "drop"
      ) |>
      dplyr::pull(permit_set) |>
      sort()
  }

  stata_sets <- canon(stata_clean)
  r_sets     <- canon(r_clean)

  n_stata <- length(stata_sets)
  n_r     <- length(r_sets)

  waldo_out <- character(0)
  passed    <- identical(stata_sets, r_sets)

  if (!passed) {
    waldo_out <- tryCatch(
      capture.output(waldo::compare(stata_sets, r_sets, x_arg = "stata", y_arg = "r")),
      error = function(e) character(0)
    )
  }

  details <- c(
    glue::glue("Distinct affiliates — Stata: {n_stata} | R: {n_r}"),
    if (passed)
      "Affiliate grouping structure matches (permit partitions identical up to ID relabeling)",
    if (!passed && n_stata != n_r)
      glue::glue("AFFILIATE COUNT MISMATCH: Stata={n_stata}, R={n_r}"),
    if (!passed && n_stata == n_r) {
      diff_sets <- which(stata_sets != r_sets)
      glue::glue("PARTITION MISMATCH: {length(diff_sets)} of {n_stata} affiliate groups differ")
    },
    if (length(waldo_out) > 0) head(waldo_out, 20)
  )
  list(passed = passed, details = details)
}

# ------------------------------------------------------------------------------
# summarize_pair_result
# Aggregates all check results for one comparison pair.
# Collects failures and warnings across all checks.
# ------------------------------------------------------------------------------
summarize_pair_result <- function(pair_label, check_results) {
  failures  <- character(0)
  warns     <- character(0)

  for (nm in names(check_results)) {
    res <- check_results[[nm]]
    if (isFALSE(res$passed)) {
      detail_str <- paste(res$details, collapse = " | ")
      failures <- c(failures, glue::glue("[{nm}] {detail_str}"))
    }
    if (length(res$warnings) > 0) {
      warns <- c(warns, glue::glue("[{nm}] {paste(res$warnings, collapse=' | ')}"))
    }
  }

  list(
    label    = pair_label,
    passed   = length(failures) == 0,
    failures = failures,
    warnings = warns,
    checks   = check_results
  )
}
