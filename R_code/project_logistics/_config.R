# ==============================================================================
# Script:      _config.R
# Converted from: folder_setup_globals.do
# Repository:  READ-SSB-Lee-RFAdataset
# ------------------------------------------------------------------------------
# Purpose:
#   Shared configuration for the RFA dataset R pipeline. Source this file at
#   the top of each script that needs shared  parameters or scalars.
#   Equivalent to running folder_setup_globals.do in Stata. Directories removed
#
# Pipeline Position:
#   Step 0 . Must be sourced before any other script.
#
# Inputs:
#   - System date (Sys.Date())
#
# Outputs:
#   - No files.
#   - Defines all shared R variables used by extraction and processing scripts.
#   - sets up data folder paths
# ODBC Connections Required:
#  set oustide of this
# Globals → R Config:
#   - $vintage_string  → vintage_string : date-stamped output filename suffix
#   - $yr_select       → yr_select      : analysis year (most recent complete year)
#   - $firstyr         → firstyr        : start of 5-year revenue window (set in wrapper)
#   - $sba_comm        → sba_comm       : commercial SBA size threshold ($11M)
#   - $sba_forhire     → sba_forhire    : for-hire SBA size threshold ($8M)
#   - scalars C*       → cpi            : named vector of CPI-U HALF2 values
#   - scalars rec_exp* → rec_exp        : named vector of expenditure-per-angler scalars
#
# Conversion Notes:
#   - rec_exp2023 through rec_exp2025  are CPI-extrapolated from the 2022 survey value.
#

# Note, you should eventually pull the data from CPI, instead of looking it up
# every year from the website
# ==============================================================================

#Deal with paths
intermediate_path <- here("data_folder", "intermediate")
dir.create(intermediate_path, recursive = TRUE, showWarnings = FALSE)
final_path <- here("data_folder", "final")
dir.create(final_path, recursive = TRUE, showWarnings = FALSE)


library(fs)
library(lubridate)

today       <- Sys.Date()
this_year   <- year(today)
this_month  <- month(today)
this_day    <- day(today)

today_date_string <- format(today, "%Y_%m_%d")

if (this_month >= 6) {
  yr_select          <- this_year - 1L
  yr_permit_portfolio <- this_year
} else {
  yr_select          <- this_year - 2L
  yr_permit_portfolio <- this_year - 1L
}

# permit_date_pull: string used literally inside Oracle SQL, including single quotes
permit_date_pull <- glue::glue("'06/01/{yr_permit_portfolio}'")

if (this_month < 6) {
  vintage_string <- paste0("PROTOTYPE_", today_date_string)
  message("Today is ", format(today, "%Y %m %d"),
          "\nIt is before the Jun 1 permit cutoff, so this data is preliminary.")
} else {
  vintage_string <- today_date_string
}

# firstyr is set in wrapper_extraction.R (depends on yr_select)

# ------------------------------------------------------------------------------
# CPI-U scalars (BLS series CUUR0000SA0, HALF2 values)
# Source: https://data.bls.gov/timeseries/CUUR0000SA0
# Update C2025 with the actual BLS HALF2 value before the 2026 annual run.
# ------------------------------------------------------------------------------

cpi <- c(
  "2010" = 218.056,
  "2011" = 224.939,
  "2012" = 229.594,
  "2013" = 232.957,
  "2014" = 237.088,
  "2015" = 237.739,
  "2016" = 241.237,
  "2017" = 246.163,
  "2018" = 252.125,
  "2019" = 256.903,
  "2020" = 260.065,
  "2021" = 275.703,
  "2022" = 296.963,
  "2023" = 306.996,
  "2024" = 315.233,
  "2025" = 324,
  "2026" = 1000000   # HARD-CODED: sentinel
)

# ------------------------------------------------------------------------------
# Expenditure-per-angler scalars (rec_exp)
# Survey values through 2022 from Scott's For-Hire_Fee.xlsx (DataSet2 sheet).
# 2023–2025 are CPI-extrapolated from the 2022 base; 2025 uses the sentinel CPI.
# See documentation/input_data_docs/ForHire_Methods.docx for methodology.
# ------------------------------------------------------------------------------

rec_exp <- c(
  "2010" = 103.56,
  "2011" = 113.44,
  "2012" = 116.15,
  "2013" = 118.86,
  "2014" = 121.57,
  "2015" = 124.28,
  "2016" = 126.99,
  "2017" = 129.69,
  "2018" = 132.40,
  "2019" = 135.11,
  "2020" = 137.82,
  "2021" = 140.53,
  "2022" = 143.24
)

# CPI-extrapolated values for 2023+
rec_exp["2023"] <- round(rec_exp["2022"] * cpi["2023"] / cpi["2022"], 2)
rec_exp["2024"] <- round(rec_exp["2022"] * cpi["2024"] / cpi["2022"], 2)
rec_exp["2025"] <- round(rec_exp["2022"] * cpi["2025"] / cpi["2022"], 2)

# ------------------------------------------------------------------------------
# SBA small-business size thresholds
# ------------------------------------------------------------------------------

# Commercial fishing: $11M (80 FR 249, NMFS 2015 rule, page 81194)
sba_comm    <- 11000000L

# For-hire: $8M (84 FR 34261, effective July 2019 — inflation adjustment)
# NOTE: $7.5M was the prior standard (80 FR 249); now dead code in original .do file.
sba_forhire <-  8000000L

