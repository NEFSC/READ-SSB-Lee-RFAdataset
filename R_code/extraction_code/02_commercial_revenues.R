# ==============================================================================
# Script:      02_commercial_revenues.R
# Converted from: 02_commercial_revenues.do
# Repository:  READ-SSB-Lee-RFAdataset
# ------------------------------------------------------------------------------
# Purpose:
#   Pulls commercial landing values from CAMS for a 5-year window ending at
#   yr_select. Aggregates by permit, year, and ITIS TSN (species code), then
#   reshapes to wide so each row is a permit-year with one value_NNNNNN column
#   per species, plus a permit-level commercial total column.
#
# Pipeline Position:
#   Step 1b of 4 (extraction). Reads from Oracle. Produces input for data_joins.R.
#
# Inputs:
#   - DB: cams_land
#
# Outputs:
#   - data_folder/intermediate/commercial_revenues_<vintage>.Rds
#     Columns: permit, year, value_permit_commercial, value_NNNNNN per ITIS TSN
#
# Oracle Connections Required:
#   - DSN: nefscdb_con, set up as an ROracle connection dbConnect() outside of this code
#
# Globals → R Config:
#   - $firstyr     → firstyr       : first year of 5-year window (set in wrapper)
#   - $yr_select   → yr_select     : last year of window
#   - $my_datadir  → my_datadir    : data folder path
#   - $vintage_string → vintage_string
#
# Conversion Notes:
#   - Administrative dummy permit codes excluded: 190998, 290998, 390998, 490998, 000000.
#   - `renvars, lower` in original lowercased column names after ODBC load;
#     replicated via tolower() on names(df).
#   - `compress` in Stata is implicit in R (no action needed).
#
# ==============================================================================

# firstyr must be set by wrapper_extraction.R before this script runs
stopifnot("firstyr must be defined (run wrapper_extraction.R first)" = exists("firstyr"))

# ------------------------------------------------------------------------------
# Connect and query
# ------------------------------------------------------------------------------

con<-eval(nefscdb_con)

query <- glue("
  select permit, year, sum(nvl(value, 0)) as value, itis_tsn
  from cams_garfo.cams_land cl
  where cl.year between {firstyr} and {yr_select}
    and itis_tsn is not NULL
    and itis_tsn <> 0
  group by permit, year, itis_tsn
")

df <- dbGetQuery(con, query)
dbDisconnect(con)

names(df) <- tolower(names(df))

message("check3: ", nrow(df), " rows loaded from CAMS")

# ------------------------------------------------------------------------------
# Cleanup: coerce types, drop dummy permit codes
# ------------------------------------------------------------------------------

df <- df %>%
  mutate(
    permit   = as.integer(permit),
    year     = as.integer(year),
    itis_tsn = as.character(itis_tsn)
  ) %>%
  filter(!permit %in% c(190998L, 290998L, 390998L, 490998L, 0L))

# ------------------------------------------------------------------------------
# Compute permit-level commercial total (replaces the ZZZZZZ sentinel approach)
# Stata: preserve; collapse (sum) value_, by(permit year); gen itis_tsn="ZZZZZZ"; append
# ------------------------------------------------------------------------------

totals <- df %>%
  group_by(permit, year) %>%
  summarise(value_permit_commercial = sum(value, na.rm = TRUE), .groups = "drop")

# ------------------------------------------------------------------------------
# Reshape wide: one column per ITIS TSN  (value_NNNNNN)
# Stata: rename value value_; reshape wide value_, i(permit year) j(itis_tsn) string
# ------------------------------------------------------------------------------

df_wide <- df %>%
  mutate(itis_tsn = paste0("value_", itis_tsn)) %>%
  pivot_wider(
    id_cols     = c(permit, year),
    names_from  = itis_tsn,
    values_from = value,
    values_fill = 0
  )

# Join permit-level commercial total
df_wide <- df_wide %>%
  left_join(totals, by = c("permit", "year"))


df_wide<-df_wide %>%
  arrange(permit,year)

# ------------------------------------------------------------------------------
# Save
# ------------------------------------------------------------------------------

out_path <- here("data_folder", "intermediate",
                     glue("commercial_revenues_{vintage_string}.Rds"))
saveRDS(df_wide, out_path)
message("Saved: ", out_path, " (", nrow(df_wide), " permit-year rows, ",
        ncol(df_wide), " columns)")
