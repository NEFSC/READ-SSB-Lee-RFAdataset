# ==============================================================================
# verify_port.R
# Port verification: Stata .dta outputs vs R .Rds outputs
# Repository: READ-SSB-Lee-RFAdataset
#
# Usage:
#   source("R_code/verify_port.R")   — or run interactively section by section
#   Rscript R_code/verify_port.R
#
# Outputs:
#   - Console: live progress log
#   - File:    verification-report.md  (written to project root)
#
# Tolerance: 1e-6 default (see TOLERANCE CONFIGURATION section to override)
#
# Prerequisites:
#   - All Stata .dta outputs and R .Rds outputs must exist on disk.
#   - vintage_string must match the string used when the pipeline was run.
#     By default, this script sources _config.R which derives vintage_string
#     from Sys.Date(). Override manually (see MANUAL OVERRIDE section) if
#     verifying outputs produced on a different date.
#
# Comparison strategy:
#   1. Primary: affiliates_{vintage_string}.dta vs .Rds (final output)
#   2. If primary PASSES → report PASS, no further testing needed.
#   3. If primary FAILS  → also run the four intermediate-file pairs to
#      help diagnose where the divergence originated.
#   "affiliates_condensed" is NOT tested (per session instructions).
#
# NOTE: affiliate_id values are NEVER compared directly. Instead, check_affiliate_structure()
#       verifies that the partition of permits into groups is structurally equivalent.
# ==============================================================================

here::i_am("R_code/verify_port.R")

# 1. Load packages
# ------------------------------------------------------------------------------
library(here)
library(tidyverse)
library(haven)
library(fs)
library(glue)
library(waldo)
# waldo loaded conditionally in verify_helpers.R

# 2. Source helpers
# ------------------------------------------------------------------------------
source(here("R_code", "verify_helpers.R"))

# 3. Source _config.R for vintage_string, yr_select, this_month
#    This derives vintage_string from today's date, matching the naming
#    convention used by the pipeline scripts.
# NOTE: If you are verifying outputs produced on a DIFFERENT date than today,
#       comment out the source() call and set vintage_string manually below.
# ------------------------------------------------------------------------------
source(here("R_code", "project_logistics","_config.R"))

# ==============================================================================
# MANUAL OVERRIDE SECTION
# If vintage_string from _config.R does not match the filenames on disk, because
# you are runing this on a different day that the data extraction,
# uncomment and edit the line below:
# ------------------------------------------------------------------------------
# vintage_string <- "PROTOTYPE_2026_05_07"     # replace with the actual vintage from filenames
# yr_select      <- 2024L            # replace with the corresponding analysis year
# ==============================================================================

message("vintage_string = ", vintage_string)
message("yr_select      = ", yr_select)

# 4. TOLERANCE CONFIGURATION
# ------------------------------------------------------------------------------
# Default tolerance for all numeric comparisons.
DEFAULT_TOLERANCE <- 1e-6

# Per-variable overrides (add entries as needed based on known precision differences).
# Example: value_permit_forhire may have 1-unit rounding differences due to
# Stata vs R round() behavior (Stata uses standard rounding; R uses banker's rounding
# in some versions). If rounding discrepancies appear, raise tolerance for that column.
# NOTE: value_permit_forhire uses round(anglers * rec_exp) — difference of 1 possible.
# There are some variable that are created as sums of rounded values. So, I've set a pretty loose
# tolerance here.

VARIABLE_TOLERANCES <- c(
  "value_permit_forhire" = 1,
  "affiliate_total" = 3,
  "affiliate_fish" = 2,
  "affiliate_forhire" = 2,
  "value_permit" = 2

)

get_tolerance <- function(varname) {
  if (varname %in% names(VARIABLE_TOLERANCES)) {
    VARIABLE_TOLERANCES[[varname]]
  } else {
    DEFAULT_TOLERANCE
  }
}

# 5. COMPARISON PAIRS
# ------------------------------------------------------------------------------
# Derived from phase1-report.md Section 5 (pipeline map) and phase2-master-doc.md
# Section 5 (intermediate file map).
#
# Primary pair tested first. Secondary pairs only tested if primary fails.
# "affiliates_condensed" is explicitly excluded (per session instructions).
#
# NOTE: paths use here::here() anchored to the project root (.Rproj location).
#       Update if your data_folder is in a non-standard location.
# ------------------------------------------------------------------------------

# Dynamic entity type column name (e.g., "entity_type_2024")
entity_col <- paste0("entity_type_", yr_select)

primary_pair <- list(
  label  = "affiliates_final",
  stata  = here("data_folder", "final", glue("affiliates_{vintage_string}.dta")),
  r      = here("data_folder", "final", glue("affiliates_{vintage_string}.Rds")),
  script = "data_joins.do / data_joins.R",
  notes  = paste0(
    "Final output panel: one row per permit per year over 5-year window. ",
    "Contains ", entity_col, ", small_business, affiliate-level revenue aggregates, ",
    "permit plan-category indicators (HRG_A, BSB_1, etc.), and species-level revenue ",
    "columns (value_NNNNNN). value_permit_commercial is DROPPED from both outputs. ",
    "affiliate_id exact values are not compared (arbitrary sequential integers)."
  )
)

# NOTE: Secondary pairs are only compared if the primary pair FAILS.
secondary_pairs <- list(
  list(
    label  = "ownership_intermediate",
    stata  = here("data_folder", "intermediate", glue("ownership_{vintage_string}.dta")),
    r      = here("data_folder", "intermediate", glue("ownership_{vintage_string}.Rds")),
    script = "01_extract_ownership.do / 01_extract_ownership.R",
    notes  = paste0(
      "One row per permit for yr_select. Columns: affiliate_id, year, permit, person_id1...N. ",
      "affiliate_id exact values not compared (arbitrary). ",
      "Sentinel person_id1 = 99000000 + vp_num for permits with no ownership records."
    )
  ),
  list(
    label  = "commercial_revenues_intermediate",
    stata  = here("data_folder", "intermediate", glue("commercial_revenues_{vintage_string}.dta")),
    r      = here("data_folder", "intermediate", glue("commercial_revenues_{vintage_string}.Rds")),
    script = "02_commercial_revenues.do / 02_commercial_revenues.R",
    notes  = paste0(
      "Wide panel: one row per permit-year, one value_NNNNNN column per ITIS TSN species. ",
      "value_permit_commercial = permit-level 5-year total. ",
      "R version computes permit total separately (no ZZZZZZ sentinel), but values should match. ",
      "Administrative dummy permit codes 190998/290998/390998/490998/0 excluded from both."
    )
  ),
  list(
    label  = "recreational_intermediate",
    stata  = here("data_folder", "intermediate", glue("recreational_{vintage_string}.dta")),
    r      = here("data_folder", "intermediate", glue("recreational_{vintage_string}.Rds")),
    script = "03_for_hire_revenues.do / 03_for_hire_revenues.R",
    notes  = paste0(
      "Columns: permit, year, anglers, value_permit_forhire. ",
      "value_permit_forhire = round(anglers * rec_exp[year]). ",
      "Rounding differences of ±1 are expected and tolerated (VARIABLE_TOLERANCES)."
    )
  ),
  list(
    label  = "permits_intermediate",
    stata  = here("data_folder", "intermediate", glue("permits_{vintage_string}.dta")),
    r      = here("data_folder", "intermediate", glue("permits_{vintage_string}.Rds")),
    script = "04_permit_portfolio.do / 04_permit_portfolio.R",
    notes  = paste0(
      "Columns: permit, year, pppHRG_A, pppBSB_1, ... (ppp prefix NOT yet stripped here; ",
      "stripping happens in data_joins). 5 rows per permit covering firstyr:yr_select. ",
      "Values are binary 0/1 indicators."
    )
  )
)

# Track files that cannot be found (will be reported in MISSING_PAIRS)
MISSING_PAIRS <- list()

# 6. PRE-FLIGHT CHECKS
# ------------------------------------------------------------------------------
message("\n=== PRE-FLIGHT: checking all files exist ===")

preflight_table <- data.frame(
  label        = character(0),
  stata_path   = character(0),
  stata_exists = logical(0),
  r_path       = character(0),
  r_exists     = logical(0)
)

all_pairs <- c(list(primary_pair), secondary_pairs)
for (pair in all_pairs) {
  stata_ok <- fs::file_exists(pair$stata)
  r_ok     <- fs::file_exists(pair$r)
  preflight_table <- rbind(preflight_table, data.frame(
    label        = pair$label,
    stata_path   = pair$stata,
    stata_exists = stata_ok,
    r_path       = pair$r,
    r_exists     = r_ok,
    stringsAsFactors = FALSE
  ))
  if (!stata_ok || !r_ok) {
    MISSING_PAIRS[[pair$label]] <- list(
      stata_missing = !stata_ok,
      r_missing     = !r_ok,
      stata_path    = pair$stata,
      r_path        = pair$r
    )
    message("  MISSING: ", pair$label,
            if (!stata_ok) paste0("\n    Stata: ", pair$stata),
            if (!r_ok)     paste0("\n    R:     ", pair$r))
  } else {
    message("  OK: ", pair$label)
  }
}

# 7. MAIN COMPARISON LOOP
# ------------------------------------------------------------------------------
all_results <- list()
run_secondary <- FALSE

run_pair <- function(pair) {
  lbl <- pair$label
  message("\n--- Comparing: ", lbl, " ---")

  if (lbl %in% names(MISSING_PAIRS)) {
    message("  SKIPPED (files missing)")
    return(list(
      label   = lbl,
      passed  = FALSE,
      skipped = TRUE,
      failures = c("One or more files missing — see PRE-FLIGHT section"),
      warnings = character(0),
      checks  = list()
    ))
  }

  message("  Reading Stata .dta ...")
  stata_df <- haven::read_dta(pair$stata) |>
    haven::zap_formats() |>
    haven::zap_widths()

  message("  Reading R .Rds ...")
  r_df <- readRDS(pair$r)

  message("  Running checks ...")

  results <- list(
    dimensions    = check_dimensions(stata_df, r_df, lbl),
    column_names  = check_column_names(stata_df, r_df, lbl),
    column_types  = check_column_types(stata_df, r_df, lbl),
    missing_vals  = check_missing_values(stata_df, r_df, lbl),
    factor_levels = check_factor_levels(stata_df, r_df, lbl),
    values        = check_values(stata_df, r_df, lbl,
                                 skip_cols = c("affiliate_id"))
  )

  # Affiliate structure check (only where affiliate_id is meaningful)
  if ("affiliate_id" %in% tolower(names(stata_df))) {
    results$affiliate_structure <- check_affiliate_structure(stata_df, r_df, lbl)
  }

  summary <- summarize_pair_result(lbl, results)
  summary$skipped <- FALSE

  status <- if (summary$passed) "PASS" else "FAIL"
  message(glue::glue("  {lbl}: {status} ({length(summary$failures)} failures, {length(summary$warnings)} warnings)"))

  summary
}

# Run primary pair
message("\n=== PRIMARY COMPARISON ===")
primary_result <- run_pair(primary_pair)
all_results[[primary_pair$label]] <- primary_result

if (!primary_result$passed && !isTRUE(primary_result$skipped)) {
  message("\nPrimary pair FAILED — running secondary (intermediate) pairs to diagnose root cause.")
  run_secondary <- TRUE
} else if (primary_result$passed) {
  message("\nPrimary pair PASSED — no secondary testing required.")
}

if (run_secondary || isTRUE(primary_result$skipped)) {
  message("\n=== SECONDARY COMPARISONS (intermediates) ===")
  for (pair in secondary_pairs) {
    all_results[[pair$label]] <- run_pair(pair)
  }
}

# 8. ROLL-UP SUMMARY
# ------------------------------------------------------------------------------
n_total    <- length(all_results)
n_passed   <- sum(vapply(all_results, function(r) isTRUE(r$passed),  logical(1)))
n_failed   <- sum(vapply(all_results, function(r) isFALSE(r$passed) && !isTRUE(r$skipped), logical(1)))
n_warn_only <- sum(vapply(all_results, function(r)
  isTRUE(r$passed) && length(r$warnings) > 0, logical(1)))
n_skipped  <- sum(vapply(all_results, function(r) isTRUE(r$skipped), logical(1)))
n_missing  <- length(MISSING_PAIRS)

overall_pass <- primary_result$passed && !isTRUE(primary_result$skipped)

message("\n=== SUMMARY ===")
message("Pairs run:     ", n_total)
message("Passed:        ", n_passed)
message("Failed:        ", n_failed)
message("Warn-only:     ", n_warn_only)
message("Skipped:       ", n_skipped)
message("Missing files: ", n_missing)
message("Overall:       ", if (overall_pass) "PASS" else "FAIL")

# 9. WRITE REPORT
# ------------------------------------------------------------------------------
report_path <- here("documentation", "stata-to-R-porting-report.md")

lines <- character(0)
add   <- function(...) { lines <<- c(lines, paste0(...)) }

add("# Port Verification Report")
add("### Repository: READ-SSB-Lee-RFAdataset")
add(glue::glue("**Run date:** {format(Sys.time(), '%Y-%m-%d %H:%M:%S')}"))
add(glue::glue("**vintage_string:** {vintage_string}"))
add(glue::glue("**yr_select:** {yr_select}"))
add(glue::glue("**Tolerance:** {DEFAULT_TOLERANCE} (default); overrides: {paste(names(VARIABLE_TOLERANCES), VARIABLE_TOLERANCES, sep='=', collapse=', ')}"))
add("")
add("---")
add("")
add("## Executive Summary")
add("")
add("| Metric | Value |")
add("|---|---|")
add(glue::glue("| Total pairs compared | {n_total} |"))
add(glue::glue("| Pairs passed (all checks) | {n_passed} |"))
add(glue::glue("| Pairs with failures | {n_failed} |"))
add(glue::glue("| Pairs with warnings only | {n_warn_only} |"))
add(glue::glue("| Pairs skipped (missing files) | {n_skipped} |"))
add(glue::glue("| Files missing | {n_missing} |"))
add("")
add(glue::glue("**Overall result: {if (overall_pass) 'PASS' else 'FAIL'}**"))
add("")
add("---")
add("")

# Pre-flight table
add("## Pre-flight File Check")
add("")
add("| Label | Stata path | Stata exists | R path | R exists |")
add("|---|---|---|---|---|")
for (i in seq_len(nrow(preflight_table))) {
  r <- preflight_table[i, ]
  add(glue::glue("| {r$label} | `{r$stata_path}` | {r$stata_exists} | `{r$r_path}` | {r$r_exists} |"))
}
add("")
add("---")
add("")

# Results by pair
add("## Results by Pair")
add("")

for (pair_label in names(all_results)) {
  res <- all_results[[pair_label]]

  # Find original pair spec for script/notes
  all_pair_specs <- c(list(primary_pair), secondary_pairs)
  pair_spec <- Filter(function(p) p$label == pair_label, all_pair_specs)[[1]]

  add(glue::glue("### {pair_label}"))
  add(glue::glue("**Script:** {pair_spec$script}"))
  add(glue::glue("**Stata file:** `{pair_spec$stata}`"))
  add(glue::glue("**R file:** `{pair_spec$r}`"))
  add(glue::glue("**Notes:** {pair_spec$notes}"))
  if (isTRUE(res$skipped)) {
    add("**Overall: SKIPPED** (one or more files missing)")
    add("")
    add("---")
    add("")
    next
  }
  add(glue::glue("**Overall: {if (res$passed) 'PASS' else 'FAIL'}**"))
  add("")

  # Check table
  add("| Check | Result | Details |")
  add("|---|---|---|")
  for (chk_name in names(res$checks)) {
    chk    <- res$checks[[chk_name]]
    status <- if (isTRUE(chk$passed)) "PASS" else if (isFALSE(chk$passed)) "FAIL" else "?"
    # Abbreviate details to first line for table
    detail_short <- if (length(chk$details) > 0) chk$details[1] else ""
    # Escape pipes in markdown table
    detail_short <- gsub("\\|", "\\\\|", substr(detail_short, 1, 120))
    add(glue::glue("| {chk_name} | {status} | {detail_short} |"))
  }
  add("")

  if (length(res$failures) > 0) {
    add("**Failures:**")
    for (f in res$failures) add(glue::glue("- {f}"))
    add("")
  }
  if (length(res$warnings) > 0) {
    add("**Warnings:**")
    for (w in res$warnings) add(glue::glue("- {w}"))
    add("")
  }
  if (res$passed && length(res$warnings) == 0) {
    add("All checks passed with no warnings.")
    add("")
  }
  add("---")
  add("")
}

# Discrepancy detail: worst rows per numeric failure
add("## Discrepancy Detail")
add("")
add("For each numeric column that failed the tolerance check, up to 20 worst-offending rows are shown (capped at 5 columns per pair).")
add("")

any_detail <- FALSE
for (pair_label in names(all_results)) {
  res <- all_results[[pair_label]]
  if (isTRUE(res$skipped)) next
  val_check <- res$checks[["values"]]
  if (is.null(val_check)) next
  wr <- val_check$worst_rows
  if (length(wr) == 0) next

  add(glue::glue("### {pair_label} — Numeric failures"))
  any_detail <- TRUE

  shown_cols <- 0
  for (col in names(wr)) {
    if (shown_cols >= 5) break
    df_wr <- wr[[col]]
    add(glue::glue("**Column: {col}**"))
    # Build markdown table header from df_wr column names
    hdr <- paste(names(df_wr), collapse = " | ")
    add(glue::glue("| {hdr} |"))
    sep <- paste(rep("---", ncol(df_wr)), collapse = " | ")
    add(glue::glue("| {sep} |"))
    for (i in seq_len(nrow(df_wr))) {
      row_vals <- vapply(seq_len(ncol(df_wr)), function(j) {
        v <- df_wr[i, j]
        if (is.numeric(v)) format(v, digits = 8) else as.character(v)
      }, character(1))
      add(glue::glue("| {paste(row_vals, collapse=' | ')} |"))
    }
    add("")
    shown_cols <- shown_cols + 1
  }
}
if (!any_detail) add("No numeric discrepancy detail to report (all numeric checks passed, or no pairs run).")
add("")
add("---")
add("")

# Diagnosis notes
add("## Diagnosis Notes")
add("")
add("For each failure, the most likely cause is indicated based on common Stata → R discrepancy patterns:")
add("")
add("| Symptom | Most likely cause |")
add("|---|---|")
add("| max_diff near 1e-7 to 1e-12 | Floating-point accumulation — R and Stata differ in intermediate precision |")
add("| max_diff of exactly 0.5 or 1 in value_permit_forhire | Rounding: Stata uses standard rounding, R may use banker's rounding |")
add("| Row count mismatch in final affiliates | Panel balancing divergence — check tidyr::complete() vs tsfill behavior |")
add("| Row count mismatch in commercial_revenues | Species column explosion or ZZZZZZ sentinel handling difference |")
add("| NA position mismatches | Extended missing values (.a/.b) in Stata vs NA in R; check conversion-notes.md REVIEW items |")
add("| Character mismatch in entity_type | Entity classification logic diverged — check affiliate_fish vs affiliate_forhire comparison at yr_select rows |")
add("| affiliate_structure FAIL | Ownership merge diverged — check full_join vs merge m:1 behavior, especially for permits only in ownership |")
add("| Permit indicator columns missing in R | ppp prefix stripping discrepancy — verify sub('^ppp','') vs renvars predrop(3) |")
add("")

# Write diagnosis for specific failures found
has_specific <- FALSE
for (pair_label in names(all_results)) {
  res <- all_results[[pair_label]]
  if (isTRUE(res$passed) || isTRUE(res$skipped)) next
  has_specific <- TRUE
  add(glue::glue("### {pair_label}"))
  for (f in res$failures) {
    add(glue::glue("- **Failure**: {f}"))
    # Provide tailored diagnosis based on failure text
    if (grepl("value_permit_forhire", f) && grepl("max_diff=", f)) {
      add("  **Likely cause**: Rounding difference (round() behavior). Stata uses standard rounding;")
      add("  R may use banker's rounding. A discrepancy of ≤1 is expected and can be tolerated by")
      add("  raising VARIABLE_TOLERANCES['value_permit_forhire'] to 1.0.")
    } else if (grepl("ROW COUNT MISMATCH", f)) {
      add("  **Likely cause**: Panel balancing divergence. Check that tidyr::complete() in data_joins.R")
      add("  produces the same rows as tsset/tsfill in data_joins.do, especially for ownership-only")
      add("  permits (REVIEW 4 in conversion-notes.md).")
    } else if (grepl("NA.*mismatch", f)) {
      add("  **Likely cause**: Extended missing values in Stata (.a/.b/.c) converted to NA in R.")
      add("  Check the specific column in conversion-notes.md REVIEW items.")
    } else if (grepl("affiliate_structure", f)) {
      add("  **Likely cause**: The m:1 merge of revenue → ownership in R (REVIEW 4 in conversion-notes.md)")
      add("  may produce different affiliate groupings than Stata's merge m:1. Check the year column")
      add("  conflict handling and ownership-only permit treatment.")
    } else if (grepl("CHARACTER.*in R", f) || grepl("NUMERIC.*in R", f)) {
      add("  **Likely cause**: Type mismatch between Stata and R. Check column type coercion in")
      add("  the relevant extraction script.")
    } else if (grepl("In Stata NOT in R|In R NOT in Stata", f)) {
      add("  **Likely cause**: Column naming divergence. Check ppp prefix stripping (renvars vs sub()),")
      add("  entity_type dynamic name, or species column naming (ITIS TSN integer formatting).")
    } else {
      add("  **Likely cause**: Review the specific check details above and compare the relevant")
      add("  section of data_joins.do vs data_joins.R.")
    }
  }
  add("")
}
if (!has_specific) add("No failures to diagnose.")
add("")
add("---")
add("")

# Missing files section
add("## Missing Files")
add("")
if (length(MISSING_PAIRS) == 0) {
  add("All expected files were found on disk.")
} else {
  add("The following files could not be found. Comparisons for these pairs were skipped.")
  add("")
  for (lbl in names(MISSING_PAIRS)) {
    mp <- MISSING_PAIRS[[lbl]]
    add(glue::glue("**{lbl}**"))
    if (mp$stata_missing) add(glue::glue("- Stata file missing: `{mp$stata_path}`"))
    if (mp$r_missing)     add(glue::glue("- R file missing: `{mp$r_path}`"))
  }
}
add("")
add("---")
add("")

# Recommended next steps
add("## Recommended Next Steps")
add("")
if (overall_pass) {
  add("The primary comparison (affiliates_final) **passed**. The R port of data_joins.R produces")
  add("output that is structurally and numerically equivalent to the Stata reference within the")
  add(glue::glue("specified tolerance ({DEFAULT_TOLERANCE})."))
  add("")
  add("1. No failures require immediate attention.")
  add("2. Review any warnings above (type-promotion from haven_labelled to numeric is expected and acceptable).")
  add("3. If the for-hire revenue tolerance was raised to 1.0, confirm with the analyst that")
  add("   ±1 dollar rounding differences are acceptable for regulatory purposes.")
} else {
  add("The primary comparison **failed**. Recommended actions:")
  add("")
  add("1. **Failures requiring immediate attention (data-integrity risk)**:")
  primary_res <- all_results[[primary_pair$label]]
  if (!isTRUE(primary_res$skipped)) {
    for (f in primary_res$failures) add(glue::glue("   - {f}"))
  }
  add("")
  add("2. **Check intermediate files** (if run) for the earliest point of divergence:")
  add("   - ownership_intermediate: if this fails, the affiliate grouping is wrong upstream")
  add("   - commercial_revenues_intermediate: if this fails, species revenue values diverged at extraction")
  add("   - recreational_intermediate: if this fails, for-hire revenue calculation diverged")
  add("   - permits_intermediate: if this fails, permit indicators diverged at extraction")
  add("")
  add("3. **Suggested edits to R conversion scripts** (by script name):")
  add("   - If ownership fails: review 01_extract_ownership.R REVIEW note (cur_group_id vs egen group)")
  add("   - If commercial fails: review 02_commercial_revenues.R REVIEW 2 (cams_land schema, ZZZZZZ handling)")
  add("   - If recreational fails: review 03_for_hire_revenues.R (rec_exp vector lookup, round() behavior)")
  add("   - If permits fail: review 04_permit_portfolio.R (ppp prefix, crossing() vs expand 5)")
  add("   - If only final fails: review data_joins.R REVIEW 4–8 in conversion-notes.md")
}
add("")
add("---")
add("")
add(glue::glue("*Report generated by verify_port.R | {format(Sys.time(), '%Y-%m-%d %H:%M:%S')}*"))

writeLines(lines, report_path)
message("\nReport written to: ", report_path)
message("Done.")
