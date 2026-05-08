# ==============================================================================
# Script:      01_extract_ownership.R
# Converted from: 01_extract_ownership.do
# Repository:  READ-SSB-Lee-RFAdataset
# ------------------------------------------------------------------------------
# Purpose:
#   Constructs a permit-to-affiliate mapping for year yr_select. Pulls person IDs
#   associated with each vessel permit, reshapes to wide so each row represents a
#   unique combination of owners, then assigns a common affiliate_id to permits
#   with identical ownership structures using group indexing.
#
# Pipeline Position:
#   Step 1a of 4 (extraction). Reads from Oracle. Produces input for data_joins.R.
#
# Inputs:
#   - DB: nefsc_garfo.permit_vps_owner      (via nefscdb_con)
#   - DB: nefsc_garfo.client_bus_own        (via nefscdb_con)
#   - DB: nefsc_garfo.permit_vps_fishery_ner (via nefscdb_con)
#
# Outputs:
#   - data_folder/intermediate/ownership_<vintage>.Rds : permit-affiliate key file
#     Columns: affiliate_id, year, permit, person_id1...N
#
# Oracle Connections Required:
#   - DSN: nefscdb_con, set up as an ROracle connection dbConnect() outside of this code
#
# Globals → R Config:
#   - $yr_select       → yr_select      : analysis year
#   - $myNEFSC_USERS_conn → dsn_nefsc_users : ODBC DSN name
#   - $my_datadir      → my_datadir     : data folder path
#   - $vintage_string  → vintage_string : output filename suffix
#
# Conversion Notes:
#   - affiliate_id values are arbitrary sequential integers assigned by
#     cur_group_id() and will change on every re-run. Not a stable cross-vintage key.
#   - Sentinel: person_id1 = 99000000 + vp_num for permits with no ownership records.
#   - The Stata code had `sort affiliate vp_num ap_year` (line 45 of original)
#     which relied on Stata abbreviation of affiliate_id → affiliate. This is
#     a cosmetic sort before duplicates check; replicated with correct var names.
#   - The `lower` option in $myNEFSC_USERS_conn lowercased Oracle column names in Stata.
#     ROraclereturns columns in the case Oracle provides them; use tolower() here.
#   - Reminder, nested ownership is not captured. This is a documented
#     data limitation (Warning 4 in output_data_description.md). No change from Stata.
#
# ==============================================================================


con<-eval(nefscdb_con)
# ------------------------------------------------------------------------------
# Connect to Oracle and execute query
# ------------------------------------------------------------------------------

query <- glue::glue("
  select distinct(b.person_id), c.business_id, a.vp_num, a.ap_year
  from nefsc_garfo.permit_vps_owner c,
       nefsc_garfo.client_bus_own b,
       nefsc_garfo.permit_vps_fishery_ner a
  where c.ap_num in (
      select max(ap_num) as ap_num
      from nefsc_garfo.permit_vps_fishery_ner
      where ap_year = {yr_select}
      group by vp_num
  )
  and c.business_id = b.business_id
  and a.ap_num = c.ap_num
")


df <- dbGetQuery(con, query)
dbDisconnect(con)

# Lowercase column names (Stata's `lower` option in odbc load)
names(df) <- tolower(names(df))

message("check1: ", nrow(df), " rows loaded from Oracle")

# ------------------------------------------------------------------------------
# Drop business_id (not needed after linking person → permit)
# ------------------------------------------------------------------------------

df <- df %>% select(-business_id)

# ------------------------------------------------------------------------------
# Reshape wide: one row per permit-year, columns person_id1, person_id2, ...
# Stata: bysort vp_num ap_year (person_id): gen jid=_n
#        reshape wide person_id, i(vp_num ap_year) j(jid)
# ------------------------------------------------------------------------------

df <- df %>%
  arrange(vp_num, ap_year, person_id) %>%
  group_by(vp_num, ap_year) %>%
  mutate(jid = row_number()) %>%
  ungroup() %>%
  pivot_wider(
    names_from  = jid,
    values_from = person_id,
    names_prefix = "person_id"
  )

# Sort by person_id columns (equivalent to `sort person_id*` in Stata)
df <- df %>%
  arrange(across(starts_with("person_id")))

# ------------------------------------------------------------------------------
# Sentinel for permits with no ownership records
# Stata: replace person_id1=99000000+vp_num if person_id1==.
# ------------------------------------------------------------------------------

df <- df %>%
  mutate(person_id1 = if_else(is.na(person_id1), 99000000 + vp_num, person_id1))

stopifnot("person_id1 must not be missing after sentinel assignment" = all(!is.na(df$person_id1)))

# ------------------------------------------------------------------------------
# Assign affiliate_id: unique integer per distinct combination of person_id columns
# Stata: egen affiliate_id=group(person_id*), missing
# NA values in person_id columns are treated as matching other NAs (,missing option)
# ------------------------------------------------------------------------------

person_id_cols <- names(df)[startsWith(names(df), "person_id")]

df <- df %>%
  group_by(across(all_of(person_id_cols))) %>%
  mutate(affiliate_id = cur_group_id()) %>%
  ungroup() %>%
  select(affiliate_id, ap_year, vp_num, everything())

# Sort: affiliate_id, vp_num, ap_year
df <- df %>% arrange(affiliate_id, vp_num, ap_year)

# Duplicate check: no vp_num can have two affiliate_ids in the same year
dup_check <- df %>%
  distinct(vp_num, affiliate_id, ap_year) %>%
  group_by(vp_num, ap_year) %>%
  filter(n() > 1)

stopifnot("No vp_num should have >1 affiliate_id in the same year" = nrow(dup_check) == 0)

# ------------------------------------------------------------------------------
# Rename to match downstream join keys
# ------------------------------------------------------------------------------

df <- df %>%
  rename(year   = ap_year,
         permit = vp_num) %>%
  arrange(affiliate_id, year, permit)


# ------------------------------------------------------------------------------
# Save
# ------------------------------------------------------------------------------

out_path <- here("data_folder", "intermediate",
                     glue("ownership_{vintage_string}.Rds"))
saveRDS(df, out_path)
message("Saved: ", out_path)
