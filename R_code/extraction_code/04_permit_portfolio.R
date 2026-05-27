# ==============================================================================
# Script:      04_permit_portfolio.R
# Converted from: 04_permit_portfolio.do
# Repository:  READ-SSB-Lee-RFAdataset
# ------------------------------------------------------------------------------
# Purpose:
#   Extracts the plan-category permit holdings for all vessel permits active as
#   of June 1 of yr_permit_portfolio. Reshapes to wide with one binary indicator
#   column per plan-category (pppHRG_A, pppBSB_1, etc.), then expands to 5 rows
#   per permit (one per year in the revenue window firstyr:yr_select).
#
# Pipeline Position:
#   Step 1d of 4 (extraction). Reads from Oracle. Produces input for data_joins.R.
#
# Inputs:
#   - DB: NEFSC_GARFO.PERMIT_VPS_FISHERY_NER  (via DSN nova)
#
# Outputs:
#   - data_folder/intermediate/permits_<vintage>.Rds
#     Columns: permit, year, pppHRG_A, pppBSB_1, ... (one column per plan-category)
#     NOTE: the ppp prefix is stripped in data_joins.R (equivalent to `renvars ppp*, predrop(3)`)
#
# Oracle Connections Required:
#   - DSN: nefscdb_con, set up as an ROracle connection dbConnect() outside of this code
#     nefscdb_con<-dbConnect(drv, username = <your id here>, password = <your pwd here>,
#              dbname = <the tns to the production oracle database>)
#
# Globals → R Config:
#   - $permit_date_pull  → permit_date_pull : date string '06/01/YYYY' for SQL
#   - $yr_select         → yr_select        : used to set the 5-year year range
#   - $my_datadir        → my_datadir
#   - $vintage_string    → vintage_string
#
# Conversion Notes:
#   - The Stata `reshape wide ppp, i(vp) j(plancat) string` uses Stata's
#     abbreviation of vp_num → vp in the i() argument. Replicated in R using
#     the full column name vp_num.
#   - The column naming convention from Stata's reshape: ppp + plancat (no separator),
#     e.g., pppHRG_A. The ppp prefix is stripped by `renvars ppp*, predrop(3)` in
#     data_joins.R. This R script preserves the ppp prefix; stripping happens there.
#   - `expand 5 + bysort permit: replace year=year-_n+1` → tidyr::crossing() creates
#     a row for each combination of permit × year (firstyr:yr_select).
#   - `tempfile perms` was declared but unused in the original (dead code); omitted.
#   - `gen str6 plancat=plan+"_"+cat` assumes plan and cat are ≤3 chars each.
#     If Oracle returns longer strings, the str6 in Stata would truncate silently.
#     R concatenation uses full strings; add a REVIEW note if truncation is suspected.
#   - `duplicates drop` after plancat creation removes any duplicate plan-cat rows
#     per vp_num before pivoting.
#
# ==============================================================================



stopifnot("firstyr must be defined (run wrapper_extraction.R first)" = exists("firstyr"))

# ------------------------------------------------------------------------------
# Connect and query
# ------------------------------------------------------------------------------

con<-eval(nefscdb_con)

# permit_date_pull is a string like '06/01/2024' (single quotes included for Oracle SQL)
query <- glue("
  select vp_num, plan, cat
  from NEFSC_GARFO.PERMIT_VPS_FISHERY_NER
  where ap_num in (
      select max(ap_num) as ap_num
      from NEFSC_GARFO.PERMIT_VPS_FISHERY_NER
      where to_date({permit_date_pull}, 'MM/DD/YYYY')
            between trunc(start_date, 'DD') and trunc(end_date, 'DD')
      group by vp_num
  )
")

# REVIEW: verify that {permit_date_pull} interpolation produces the correct Oracle
# date string, e.g. '06/01/2024' (with single quotes already in permit_date_pull).

df <- dbGetQuery(con, query)
dbDisconnect(con)

names(df) <- tolower(names(df))

# ------------------------------------------------------------------------------
# Construct plan-category string and pivot wide
# Stata: gen str6 plancat=plan+"_"+cat; gen ppp=1; reshape wide ppp, i(vp_num) j(plancat) string
# ------------------------------------------------------------------------------

df <- df %>%
  mutate(plancat = paste0(plan, "_", cat)) %>%
  select(vp_num, plancat) %>%
  distinct() %>%                          # equivalent to `duplicates drop`
  mutate(ppp = 1L) %>%
  pivot_wider(
    names_from   = plancat,
    values_from  = ppp,
    values_fill  = 0L,
    names_prefix = "ppp"                  # produces pppHRG_A, pppBSB_1, etc.
  ) %>%
  rename(permit = vp_num)

# ------------------------------------------------------------------------------
# Expand to 5-year panel (one row per permit per year in firstyr:yr_select)
# Stata: expand 5; gen year=$yr_select; bysort permit: replace year=year-_n+1
# ------------------------------------------------------------------------------

years_df <- tibble(year = seq(firstyr, yr_select))
df <- df %>% crossing(years_df)

df<-df %>%
  arrange(permit, year)

# ------------------------------------------------------------------------------
# Save
# ------------------------------------------------------------------------------

out_path <- here("data_folder", "intermediate",
                 glue("permits_{vintage_string}.Rds"))
saveRDS(df, out_path)
message("Saved: ", out_path, " (", nrow(df), " permit-year rows, ",
        ncol(df), " columns)")
