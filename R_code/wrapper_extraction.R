# ==============================================================================
# Script:      wrapper_extraction.R
# Converted from: wrapper_extraction.do
# Repository:  READ-SSB-Lee-RFAdataset
# ------------------------------------------------------------------------------
# Purpose:
#   Extraction orchestrator. Sets firstyr, then sources the four extraction
#   scripts in pipeline order to pull ownership, commercial revenues, for-hire
#   revenues, and permit portfolio data from Oracle.
#
# Pipeline Position:
#   Step 1 of 3. Sources scripts 01-04; produces four intermediate .Rds files.
#   Sources data_joins.R
#   02_push_to_oracle.R must be run manually afterward.
#
#
# Outputs:
#   - Delegates to called scripts; see each script's header for file outputs.
#
# Oracle Connections Required:
#   - DSN: nefscdb_con, set up as an ROracle connection dbConnect() outside of this code
#
# Globals → R Config:
#   - $firstyr → firstyr : first year of 5-year revenue window
#
# Conversion Notes:
#   - The original wrapper did not call data_joins.do or 02_push_to_oracle.do;
#   - this R version DOES call data_joins, but not the push to oracle.
#   - The commented-out `erase` block (intermediate file cleanup) is omitted;
#     I prefer to keep intermediates for debugging.
#   - firstyr is set HERE  scripts 02 and 03
#     depend on it and cannot be run independently without it.
#
# ==============================================================================
library(here)
library(tidyverse)
library(ROracle)
library(glue)


here::i_am("R_code/wrapper_extraction.R")
source(here("R_code","project_logistics","_config.R"))

drv       <- dbDriver("Oracle")



# firstyr: start of 5-year revenue window (was set in wrapper_extraction.do)
firstyr <- yr_select - 4L

if (this_month < 6) {
  message("Today is ", format(today, "%Y %m %d"),
          "\nIt is before the Jun 1 permit cutoff, so this data is preliminary.")
}

message("=== Extraction pipeline starting ===")
message("yr_select = ", yr_select, " | firstyr = ", firstyr,
        " | vintage = ", vintage_string)

message("Step 1a: Ownership / affiliate key file")
source(here("R_code", "extraction_code", "01_extract_ownership.R"))

message("Step 1b: Commercial revenues")
source(here("R_code", "extraction_code", "02_commercial_revenues.R"))

message("Step 1c: For-hire revenues")
source(here("R_code", "extraction_code", "03_for_hire_revenues.R"))

message("Step 1d: Permit portfolio snapshot")
source(here("R_code", "extraction_code", "04_permit_portfolio.R"))

message("=== Extraction complete. Run data_joins.R next (manual step). ===")

source(here("R_code", "processing_code", "data_joins.R"))
