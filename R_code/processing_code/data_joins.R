# ==============================================================================
# Script:      data_joins.R
# Converted from: data_joins.do
# Repository:  READ-SSB-Lee-RFAdataset
# ------------------------------------------------------------------------------
# Purpose:
#   Central processing script. Merges all four intermediate datasets (commercial
#   revenues, for-hire revenues, ownership, and permits), fills missing affiliate
#   IDs, constructs affiliate-level aggregates, classifies entities as
#   FISHING/FORHIRE/NO_REV, determines small/large business status using SBA
#   thresholds, validates with assertion checks, and exports the final dataset.
#
# Pipeline Position:
#   Step 2 of 3. Reads four intermediate .Rds files produced by extraction scripts.
#
# Inputs:
#   - data_folder/intermediate/commercial_revenues_<vintage>.Rds
#   - data_folder/intermediate/recreational_<vintage>.Rds
#   - data_folder/intermediate/ownership_<vintage>.Rds
#   - data_folder/intermediate/permits_<vintage>.Rds
#
# Outputs:
#   - data_folder/final/affiliates_condensed_<vintage>.Rds  (subset, no species revenue)
#   - data_folder/final/affiliates_condensed_<vintage>.xlsx (same subset)
#   - data_folder/final/affiliates_<vintage>.Rds            (full dataset)
#   - data_folder/final/affiliates_<vintage>.xlsx           (full dataset)
#   Note: .sas7bdat and .Rdata outputs from Stata via Stat/Transfer are replaced by
#   native R formats (.Rds). haven::write_sas() could produce .sas7bdat if needed.
#
# ODBC Connections Required: None
#
# Globals → R Config:
#   - $my_datadir   → my_datadir
#   - $vintage_string → vintage_string
#   - $yr_select    → yr_select
#   - $sba_forhire  → sba_forhire
#   - $sba_comm     → sba_comm
#
# Conversion Notes:
#   - The two `pause;` commands (lines 81, 190 of original) are removed. They were
#     debugging artifacts that halted execution in interactive Stata.
#   - If SAS format is needed, add haven::write_sas().
#   -`local myplans ;` in original is empty (confirmed by Phase 2 as intentional).
#     The condensed export omits permit plan-category indicator columns. Add variable
#     names to condensed_extra_cols below if indicators should be included.
#   - `value_permit_commercial` is computed as the permit-level sum across species in
#     02_commercial_revenues.R. It is used here for affiliate_fish aggregate then dropped.
#
# ==============================================================================



# Dynamic entity type column name (changes annually)
entity_col <- paste0("entity_type_", yr_select)

# ------------------------------------------------------------------------------
# Load intermediate datasets
# ------------------------------------------------------------------------------

commercial <- readRDS(here("data_folder", "intermediate",
                               glue("commercial_revenues_{vintage_string}.Rds")))
forhire    <- readRDS(here("data_folder", "intermediate",
                               glue("recreational_{vintage_string}.Rds")))
ownership  <- readRDS(here("data_folder", "intermediate",
                               glue("ownership_{vintage_string}.Rds")))
permits_df <- readRDS(here("data_folder", "intermediate",
                               glue("permits_{vintage_string}.Rds")))

# ------------------------------------------------------------------------------
# Step 1: Merge commercial revenues with for-hire revenues (1:1 permit year)
# Stata: use commercial; merge 1:1 permit year using recreational; drop _merge
# ------------------------------------------------------------------------------

df <- full_join(commercial, forhire %>% select(permit, year, anglers, value_permit_forhire),
                by = c("permit", "year"))

# Fill missing revenue values with 0 (permits present in one source but not other)
df <- df %>%
  mutate(
    value_permit_forhire   = replace_na(value_permit_forhire, 0),
    value_permit_commercial = replace_na(value_permit_commercial, 0)
  )

message("check3 - revenue join: ", nrow(df), " permit-year rows")

# ------------------------------------------------------------------------------
# Step 2: Merge m:1 permit with ownership
# REVIEW: Both datasets have a `year` column. Stata's merge m:1 keeps master's year
# for _merge==1 and _merge==3 rows; for _merge==2 (ownership-only) uses using's year
# (= yr_select). Replicated here by renaming ownership year and coalescing.
# ------------------------------------------------------------------------------

# Track which permits have revenue but no ownership (equivalent to _merge==1 in Stata)
permits_with_revenue   <- unique(df$permit)
permits_with_ownership <- unique(ownership$permit)
permits_missing_ownership <- setdiff(permits_with_revenue, permits_with_ownership)

ownership_for_join <- ownership %>%
  rename(year_own = year)  # rename to avoid column conflict on join

df <- full_join(df, ownership_for_join, by = "permit") %>%
  mutate(year = coalesce(year, year_own)) %>%
  select(-year_own)

# ------------------------------------------------------------------------------
# Step 3: Balance panel (tsfill equivalent)
# After full_join, ownership-only permits have one row (year = yr_select).
# complete() adds all missing permit-year combinations.
# ------------------------------------------------------------------------------

df <- df %>%
  tidyr::complete(permit, year = seq(firstyr, yr_select))

# Fill affiliate_id and person_id columns from non-missing values within permit
# Stata: sort permit (affiliate_id); replace affiliate_id=affiliate_id[1] if ==.

person_id_cols <- names(df)[startsWith(names(df), "person_id")]

df <- df %>%
  arrange(permit, is.na(affiliate_id)) %>%   # non-missing affiliate_id first
  group_by(permit) %>%
  tidyr::fill(affiliate_id, all_of(person_id_cols), .direction = "downup") %>%
  ungroup()

# Override affiliate_id with permit number for all rows of permits missing ownership
# Stata: replace affiliate_id=permit if sum_any_miss>=1
df <- df %>%
  mutate(
    affiliate_id = if_else(
      permit %in% permits_missing_ownership,
      as.integer(permit),
      affiliate_id
    )
  )

message("check5 - ownership merge done")

# ------------------------------------------------------------------------------
# Step 4: Fill missing revenue values with 0 (after panel balancing creates new rows)
# ------------------------------------------------------------------------------

value_cols <- names(df)[startsWith(names(df), "value_")]
df <- df %>%
  mutate(across(all_of(value_cols), ~replace_na(., 0)))

# ------------------------------------------------------------------------------
# Step 5: Merge 1:1 with permit portfolio
# Stata: merge 1:1 permit year using permits.dta
# ------------------------------------------------------------------------------

df <- full_join(df, permits_df, by = c("permit", "year"))

# Fill any remaining missing affiliate_ids with permit number
df <- df %>%
  mutate(affiliate_id = if_else(is.na(affiliate_id), as.integer(permit), affiliate_id))

# Fill ppp* values with 0 for permits present in revenues/ownership but not in portfolio
ppp_cols <- names(df)[startsWith(names(df), "ppp")]
df <- df %>%
  mutate(across(all_of(ppp_cols), ~replace_na(., 0L)))

# Fill all remaining missing revenue values with 0
df <- df %>%
  mutate(across(all_of(value_cols), ~replace_na(., 0)))

message("check5 - permit portfolio merge done")

# ------------------------------------------------------------------------------
# Duplicate check: no permit can have >1 affiliate_id in the same year
# Stata: duplicates tag permit affiliate_id year, gen(mytt); assert mytt==0
# ------------------------------------------------------------------------------

dup_check <- df %>%
  distinct(permit, affiliate_id, year) %>%
  group_by(permit, year) %>%
  filter(n() > 1)

stopifnot("No permit-year should have >1 affiliate_id" = nrow(dup_check) == 0)

# ------------------------------------------------------------------------------
# Compute total permit revenue
# ------------------------------------------------------------------------------

df <- df %>%
  mutate(value_permit = value_permit_commercial + value_permit_forhire)

# ------------------------------------------------------------------------------
# Second round of affiliate_id fills (covers permits only in portfolio)
# Stata lines 94-99: fill by last, first, second observation within permit (by year)
# ------------------------------------------------------------------------------

df <- df %>%
  arrange(permit, year) %>%
  group_by(permit) %>%
  tidyr::fill(affiliate_id, .direction = "downup") %>%
  mutate(affiliate_id = if_else(is.na(affiliate_id), as.integer(permit), affiliate_id)) %>%
  ungroup()

stopifnot("affiliate_id must not be missing" = all(!is.na(df$affiliate_id)))

# ------------------------------------------------------------------------------
# Construct affiliate-level revenue aggregates (by affiliate_id × year)
# Stata: bysort affiliate_id year: egen affiliate_total=sum(value_permit)
# ------------------------------------------------------------------------------

df <- df %>%
  group_by(affiliate_id, year) %>%
  mutate(
    affiliate_total   = sum(value_permit,             na.rm = TRUE),
    affiliate_fish    = sum(value_permit_commercial,  na.rm = TRUE),
    affiliate_forhire = sum(value_permit_forhire,     na.rm = TRUE)
  ) %>%
  ungroup() %>%
  arrange(affiliate_id, permit, year)

message("check6 - affiliate aggregates computed")

# Drop value_permit_commercial (was `drop value_permit_commercial` in Stata line 159)
df <- df %>% select(-value_permit_commercial)

# ------------------------------------------------------------------------------
# Classify entity type based on yr_select revenues
# Stata: gen entity_type_$yr_select="FORHIRE"; replace ="FISHING" if ...; ="NO_REV" if ...
# Project yr_select classification to all panel years
# ------------------------------------------------------------------------------

df <- df %>%
  mutate(
    !!entity_col := case_when(
      year == yr_select & affiliate_fish == 0 & affiliate_forhire == 0 ~ "NO_REV",
      year == yr_select & affiliate_fish > affiliate_forhire             ~ "FISHING",
      year == yr_select                                                  ~ "FORHIRE",
      TRUE ~ NA_character_
    )
  ) %>%
  arrange(affiliate_id, year) %>%
  group_by(affiliate_id) %>%
  tidyr::fill(!!sym(entity_col), .direction = "updown") %>%  # propagate yr_select value to all years
  ungroup()

stopifnot("All rows must have entity_type classified" =
            all(!is.na(df[[entity_col]])))

message("check7 - entity classification done")

# ------------------------------------------------------------------------------
# Compute affiliate average annual revenue (for SBA size determination)
# Stata: affiliate_bar = sum(value_permit) / count of unique years for affiliate
# This is the 5-year average annual total revenue of the affiliate.
# ------------------------------------------------------------------------------

df <- df %>%
  group_by(affiliate_id) %>%
  mutate(
    affiliate_bar = sum(value_permit, na.rm = TRUE) / n_distinct(year)
  ) %>%
  ungroup()

# Classify small/large business
df <- df %>%
  mutate(
    small_business = 1L,
    small_business = if_else(
      .data[[entity_col]] == "FORHIRE" & affiliate_bar >= sba_forhire,
      0L, small_business
    ),
    small_business = if_else(
      .data[[entity_col]] == "FISHING" & affiliate_bar >= sba_comm,
      0L, small_business
    )
  )

# Logic check: no FISHING small entity should exceed the commercial threshold
check_df <- df %>%
  filter(
    (.data[[entity_col]] == "FISHING"  & small_business == 1L & affiliate_bar > sba_comm) |
    (.data[[entity_col]] == "FORHIRE"  & small_business == 1L & affiliate_bar > sba_forhire)
  )
stopifnot("Logic check: no small entity should exceed its SBA threshold" = nrow(check_df) == 0)

df <- df %>% select(-affiliate_bar)

# Validation: for-hire revenue mean must be nonzero and non-missing
fh_mean <- mean(df$affiliate_forhire, na.rm = TRUE)
stopifnot("affiliate_forhire mean must not be 0 or NA" = !is.na(fh_mean) && fh_mean != 0)

message("check8 - small business classification done")

# ------------------------------------------------------------------------------
# Strip ppp prefix from permit plan-category indicators
# Stata: renvars ppp*, predrop(3)  [drops first 3 chars: pppHRG_A → HRG_A]
# checkpoint 101
# ------------------------------------------------------------------------------

ppp_cols <- names(df)[startsWith(names(df), "ppp")]
df <- df %>%
  mutate(across(all_of(ppp_cols), ~replace_na(., 0L))) %>%
  rename_with(~ sub("^ppp", "", .), all_of(ppp_cols))

message("check9 - permit indicators renamed")

# ------------------------------------------------------------------------------
# Permit count per affiliate-year
# Stata: bysort affiliate_id year: gen count_permits=_N
# ------------------------------------------------------------------------------

df <- df %>%
  group_by(affiliate_id, year) %>%
  mutate(count_permits = n()) %>%
  ungroup()

# Check that count_permits is constant within each affiliate across years
count_check <- df %>%
  group_by(affiliate_id) %>%
  summarise(count_cv = sd(count_permits) / mean(count_permits), .groups = "drop") %>%
  filter(!is.na(count_cv) & count_cv > 0)

if (nrow(count_check) > 0) {
  warning("Some affiliates have inconsistent permit counts across years: ",
          paste(count_check$affiliate_id, collapse = ", "))
}

# ------------------------------------------------------------------------------
# SD check on permit plan-category indicators (Stata lines 211-222)
# Verifies that plan-category assignments don't vary within a permit across years.
# ------------------------------------------------------------------------------

plan_prefixes <- c("BLU", "BSB", "DOG", "FLS", "HMS", "HRG", "LGC", "LO",
                   "MNK", "MUL", "OQ",  "RCB", "SCP", "SC",  "SF",  "SKT", "SMB", "TLF")
plan_pattern  <- paste0("^(", paste(plan_prefixes, collapse = "|"), ")_")
plan_vars     <- names(df)[grepl(plan_pattern, names(df))]

for (var in plan_vars) {
  sd_vals <- df %>%
    group_by(permit) %>%
    summarise(v = sd(.data[[var]], na.rm = TRUE), .groups = "drop") %>%
    pull(v)

  if (all(is.na(sd_vals) | sd_vals == 0)) {
    message("permit ", var, " is ok")
  } else {
    message("permit ", var, " has a problem")
  }
}

# ------------------------------------------------------------------------------
# Panel balance assertions
# Stata: tsset affiliate_id year; assert strongly balanced
#        tsset permit year;       assert strongly balanced
# ------------------------------------------------------------------------------

n_affiliates <- n_distinct(df$affiliate_id)
n_years      <- n_distinct(df$year)
n_permits    <- n_distinct(df$permit)

affiliate_year_count <- df %>%
  distinct(affiliate_id, year) %>%
  nrow()
stopifnot("affiliate_id-year panel must be strongly balanced" =
            affiliate_year_count == n_affiliates * n_years)

permit_year_count <- df %>%
  distinct(permit, year) %>%
  nrow()
stopifnot("permit-year panel must be strongly balanced" =
            permit_year_count == n_permits * n_years)

message("Balance checks passed: ", n_permits, " permits × ", n_years,
        " years = ", permit_year_count, " permit-year observations")

# Clean up temporary variables
df <- df %>% select(-any_of(c("value_dum", "counter", "affiliate_counter",
                               starts_with("__"))))

# Final sort
df <- df %>% arrange(affiliate_id, year, permit)

# ------------------------------------------------------------------------------
# Export
# `local myplans ;` in original is empty — condensed export omits plan-category
# indicators. Add variable names to condensed_extra_cols to include them.
# REVIEW: confirm whether permit plan-category indicators should appear in condensed export.
# ------------------------------------------------------------------------------

condensed_extra_cols <- character(0)  # was `local myplans ;` in Stata (intentionally empty)

condensed_cols <- c("affiliate_id", "year", "count_permits", entity_col,
                    "small_business", "permit",
                    "affiliate_total", "affiliate_fish", "affiliate_forhire",
                    "value_permit", "value_permit_forhire",
                    condensed_extra_cols)
# Keep only columns that exist in df
condensed_cols <- intersect(condensed_cols, names(df))

df_condensed <- df %>% select(all_of(condensed_cols))

# Rds outputs (primary)
saveRDS(df_condensed, here("data_folder", "final",
                               glue("affiliates_condensed_{vintage_string}.Rds")))
saveRDS(df,           here("data_folder", "final",
                               glue("affiliates_{vintage_string}.Rds")))

# Excel outputs (replicated from Stata export excel)

writexl::write_xlsx(df_condensed,
                    here("data_folder", "final",
                             glue("affiliates_condensed_{vintage_string}.xlsx")))
writexl::write_xlsx(df,
                    here("data_folder", "final",
                             glue("affiliates_{vintage_string}.xlsx")))


# sas xpt file

haven::write_xpt(df,
                    path=here("data_folder", "final",
                         glue("affiliates_{vintage_string}.xpt")))



message("Outputs saved to ", here("data_folder", "final"))
message("  affiliates_", vintage_string, ".Rds (", nrow(df), " rows, ", ncol(df), " cols)")
message("  affiliates_condensed_", vintage_string, ".Rds")
message("  affiliates_", vintage_string, ".xlsx")
message("  affiliates_condensed_", vintage_string, ".xlsx")
message("NOTE: .sas7bdat and .Rdata formats (previously via Stat/Transfer) not produced.")
message("      Use haven::write_sas() if SAS format is required.")

if (this_month < 6) {
  message("Today is ", format(today, "%Y %m %d"),
          "\nIt is before the Jun 1 permit cutoff, so this data is preliminary.")
}
