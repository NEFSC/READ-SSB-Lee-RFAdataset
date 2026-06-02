# ==============================================================================
# Script:      03_for_hire_revenues.R
# Converted from: 03_for_hire_revenues.do
# Repository:  READ-SSB-Lee-RFAdataset
# ------------------------------------------------------------------------------
# Purpose:
#   Computes for-hire (charter/party boat) revenue at the permit-year level by
#   extracting angler counts from VTR and multiplying by an expenditure-per-angler
#   scalar. Retains only trips of category 2 or 3 (party/charter) using handline
#   gear (GEARCODE='HND').
#
# Pipeline Position:
#   Step 1c of 4 (extraction). Reads from Oracle. Depends on firstyr (set in wrapper).
#   Produces input for data_joins.R.
#
# Inputs:
#   - DB: NEFSC_GARFO.TRIP_REPORTS_DOCUMENT  (via DSN nova)
#   - DB: NEFSC_GARFO.TRIP_REPORTS_IMAGES    (via DSN nova)
#   - rec_exp named vector (from _config.R)

# Oracle Connections Required:
#   Code assumes that you have executed this (perhaps in your .Rprofile startup script)
#   nefscdb_con<- quote(dbConnect(drv, username = id, password = novapw, dbname = tns_alias))
#   where id, novapw, and tns_alias contains the relevant connection info.
#   drv is defined in the wrapper
#
# Outputs:
#   - data_folder/intermediate/recreational_<vintage>.Rds
#     Columns: permit, year, anglers, value_permit_forhire
#
#
# Globals → R Config:
#   - $firstyr     → firstyr       : first year of 5-year window (set in wrapper)
#   - $yr_select   → yr_select     : last year of window
#   - scalars rec_expYYYY → rec_exp named vector
#
# Conversion Notes:
#   - The Stata forvalues loop iterating scalars rec_expYYYY is replaced by
#     a named vector lookup: rec_exp[as.character(year)]. Years outside the
#     defined range return NA, producing NA value_permit_forhire — this matches
#     Stata's behavior for missing scalars.
#   - rec_exp2025 is computed from the sentinel CPI; value_permit_forhire for
#     year 2025 will be obviously wrong until C2025 is updated in _config.R.
#   - Revenue is an approximation (anglers × expenditure scalar), not actual
#     reported revenue. See ForHire_Methods.docx.
#   - HND (handline) gear filter is a methodological choice per the MRIP
#     expenditure survey design, not an inadvertent restriction.
#   -  firstyr must be set by wrapper_extraction.R. If running this script
#     in isolation, set firstyr <- yr_select - 4 manually.
#
# ==============================================================================


stopifnot("firstyr must be defined (run wrapper_extraction.R first)" = exists("firstyr"))

# ------------------------------------------------------------------------------
# Connect and query
# ------------------------------------------------------------------------------
con<-eval(nefscdb_con)


query <- glue("
  select VESSEL_PERMIT_NUM as permit,
         extract(YEAR FROM DATE_SAIL) as year,
         sum(nvl(nanglers, 0)) as anglers
  from NEFSC_GARFO.TRIP_REPORTS_DOCUMENT
  where (tripcatg between 2 and 3)
    and docid in (
        select distinct docid
        from NEFSC_GARFO.TRIP_REPORTS_IMAGES
        where GEARCODE = 'HND'
    )
    and extract(YEAR FROM DATE_SAIL) between {firstyr} and {yr_select}
  group by VESSEL_PERMIT_NUM, extract(YEAR FROM DATE_SAIL)
")

df <- dbGetQuery(con, query)
dbDisconnect(con)

names(df) <- tolower(names(df))

# ------------------------------------------------------------------------------
# Compute for-hire revenue: anglers × expenditure scalar
# Stata: forvalues yr = $firstyr(1)$yr_select { replace rec_exp=scalar(rec_expYYYY) if year==`yr' }
# ------------------------------------------------------------------------------

df <- df %>%
  mutate(
    permit  = as.integer(permit),
    year    = as.integer(year),
    anglers = as.numeric(anglers),
    # Named vector lookup: returns NA for years not in rec_exp (e.g., yr_select >= 2026)
    rec_exp_val = rec_exp[as.character(year)],
    value_permit_forhire = round(anglers * rec_exp_val)
  ) %>%
  select(-rec_exp_val) %>%
  arrange(permit, year)

# ------------------------------------------------------------------------------
# Save
# ------------------------------------------------------------------------------

out_path <- here("data_folder", "intermediate",
                 glue("recreational_{vintage_string}.Rds"))
saveRDS(df, out_path)
message("Saved: ", out_path, " (", nrow(df), " permit-year rows)")
