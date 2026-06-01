# ==============================================================================
# Script:      02_push_to_oracle.R
# Converted from: 02_push_to_oracle.do
# Repository:  READ-SSB-Lee-RFAdataset
# ------------------------------------------------------------------------------
# Purpose:
#   Reads the final affiliates dataset (current year only), drops a prior-year
#   Oracle table (mlee.RFA{next_year}), creates a fresh table, inserts the data,
#   and grants SELECT privileges to named colleagues.
#
# Pipeline Position:
#   Step 3 of 3. Run manually after data_joins.R completes.
#   Reads: data_folder/final/affiliates_<vintage>.Rds
#   Writes: Oracle table mlee.RFA{next_year}
#
# Inputs:
#   - data_folder/final/affiliates_<vintage>.Rds
#
# Outputs:
#   - Oracle table: mlee.RFA{next_year} (DROP/CREATE/INSERT/GRANT)
#     Columns: affiliate_id, entity_type_{yr_select}, small_business, permit,
#              value_permit, value_permit_forhire, year
#
# ODBC Connections Required:
#   - DSN: nova  (was $mynova_conn for DDL, $myNEFSC_USERS_conn for INSERT in Stata)
#   Both pointed to the same Oracle server. In R/DBI, one connection handles all operations.
#
# Globals → R Config:
#   - $my_datadir    → my_datadir
#   - $vintage_string → vintage_string
#   - $yr_select     → yr_select
#   - $mynova_conn + $myNEFSC_USERS_conn → dsn_nova (same server, single connection in R)
#
# Conversion Notes:
#   - The `oracle_no_lower` local workaround in Stata (stripping "lower" from the
#     connection string to allow DDL without column-name lowercasing) is not needed
#     in R/DBI. DBI executes DDL statements directly; column casing is controlled
#     by the SQL strings themselves.
#   - REVIEW: The original Stata script uses `entity_type_` as an abbreviated
#     variable name for `entity_type_{yr_select}`. This R script uses the full
#     column name explicitly via the entity_col variable. Verify the Oracle column
#     name matches the CREATE TABLE DDL below.
#   - The commented-out GARFO JDBC block (lines 43-59 of original) is omitted;
#     those credentials/privileges are not available.
#   - DBI::dbWriteTable with overwrite=TRUE replaces the DROP+CREATE TABLE pattern.
#     The explicit CREATE TABLE DDL with typed columns is replicated via dbExecute
#     if strict Oracle types are required; see REVIEW comment below.
#   - REVIEW: DBI::dbWriteTable may map R types to Oracle types differently than
#     the hand-coded DDL (NUMBER(8), VARCHAR2(8 CHAR), NUMBER(1), NUMBER(6), FLOAT,
#     NUMBER(4)). If exact Oracle type definitions are required, use the explicit
#     DDL approach shown in the commented block below.
#
# Converted: Phase 3 automated conversion pass
# ==============================================================================

library(tidyverse)
library(DBI)
library(ROracle)
library(glue)
library(fs)
library(here)

here::i_am("R_code/processing_code/02_push_to_oracle.R")

source(here("R_code", "project_logistics","_config.R"))
drv       <- dbDriver("Oracle")

con<-eval(nefscdb_con)

next_year  <- yr_select + 1L
entity_col <- glue("entity_type_{yr_select}")
table_name <- glue("RFA{next_year}")
entity_upper <- glue("ENTITY_TYPE_{yr_select}")

# ------------------------------------------------------------------------------
# Load final dataset, filter to current year, select columns for Oracle push
# ------------------------------------------------------------------------------

affiliates <- readRDS(here("data_folder", "final",
                               paste0("affiliates_", vintage_string, ".Rds")))

df_push <- affiliates %>%
  filter(year == yr_select) %>%
  select(affiliate_id, all_of(entity_col), small_business,
         permit, value_permit, value_permit_forhire, year) %>%
#  rename(permit_year = year)%>%
  arrange(affiliate_id, permit)
names(df_push) <- toupper(names(df_push))

message("Rows to push: ", nrow(df_push))

# ------------------------------------------------------------------------------
# Connect to Oracle
# In Stata, mynova_conn was used for DDL; myNEFSC_USERS_conn for INSERT.
# Both are the same physical server. One DBI connection handles both in R.
# ------------------------------------------------------------------------------
con<-eval(nefscdb_con)

# ------------------------------------------------------------------------------
# DROP existing table (capture failure if table doesn't exist)
# Stata: capture odbc exec("DROP TABLE mlee.RFA${next_year}")
# ------------------------------------------------------------------------------

sql<-glue("DROP TABLE mlee.{table_name}")

tryCatch(
  DBI::dbExecute(con, sql),
  error = function(e) message("DROP TABLE failed (table may not exist): ", e$message)
)

# ------------------------------------------------------------------------------
# CREATE TABLE with explicit Oracle column types
# Replicates the hand-coded DDL from the original script.
# REVIEW: if DBI::dbWriteTable type inference is acceptable, replace the
# dbExecute(CREATE TABLE) + dbWriteTable(append=TRUE) pattern with a single
# dbWriteTable(..., overwrite=TRUE) call.
# ------------------------------------------------------------------------------

create_sql <- glue("
  CREATE TABLE MLEE.{table_name} (
    AFFILIATE_ID           NUMBER(8),
    {entity_upper}         VARCHAR2(8 CHAR),
    SMALL_BUSINESS         NUMBER(1),
    PERMIT                 NUMBER(6),
    VALUE_PERMIT           FLOAT,
    VALUE_PERMIT_FORHIRE   FLOAT,
    YEAR             NUMBER(4)
  )
")

DBI::dbExecute(con, create_sql)

# ------------------------------------------------------------------------------
# INSERT data
# Stata: odbc insert ... table("mlee.RFA${next_year}")
# ------------------------------------------------------------------------------

tablename<- glue("{table_name}")

DBI::dbWriteTable(
  con,
  name   =glue("{tablename}"),
  value  = df_push,
  append = TRUE
)

message("Inserted ", nrow(df_push), " rows into mlee.", table_name)

# ------------------------------------------------------------------------------
# GRANT SELECT to colleagues
# Stata: odbc exec("GRANT SELECT on mlee.RFA${next_year} to CDEMAREST, ...")
# HARD-CODED: grant recipients (CDEMAREST, GARDINI, JDIDDEN, NPRADHAN, RMURPHY, SWERNER, GARFO_NESFC)
# ------------------------------------------------------------------------------

grant_sql <- glue::glue("
  GRANT SELECT ON mlee.{table_name}
  TO CDEMAREST, GARDINI, JDIDDEN, NPRADHAN, RMURPHY, SWERNER,GARFO_NESFC
")

DBI::dbExecute(con, grant_sql)
message("GRANT SELECT executed on mlee.", table_name)

DBI::dbDisconnect(con)
message("Oracle push complete: mlee.", table_name)

# NOTE: The commented-out GARFO JDBC block (GRANT to BGALUARDI) is omitted.
# No CREATE TABLE privileges exist on the GARFO server per original comment.

