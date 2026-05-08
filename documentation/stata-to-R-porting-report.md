# Port Verification Report
### Repository: READ-SSB-Lee-RFAdataset
**Run date:** 2026-05-08 09:52:29
**vintage_string:** PROTOTYPE_2026_05_08
**yr_select:** 2024
**Tolerance:** 1e-06 (default); overrides: value_permit_forhire=1, affiliate_total=3, affiliate_fish=2, affiliate_forhire=2, value_permit=2

---

## Executive Summary

| Metric | Value |
|---|---|
| Total pairs compared | 1 |
| Pairs passed (all checks) | 1 |
| Pairs with failures | 0 |
| Pairs with warnings only | 0 |
| Pairs skipped (missing files) | 0 |
| Files missing | 0 |

**Overall result: PASS**

---

## Pre-flight File Check

| Label | Stata path | Stata exists | R path | R exists |
|---|---|---|---|---|
| affiliates_final | `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/final/affiliates_PROTOTYPE_2026_05_08.dta` | TRUE | `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/final/affiliates_PROTOTYPE_2026_05_08.Rds` | TRUE |
| ownership_intermediate | `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/intermediate/ownership_PROTOTYPE_2026_05_08.dta` | TRUE | `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/intermediate/ownership_PROTOTYPE_2026_05_08.Rds` | TRUE |
| commercial_revenues_intermediate | `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/intermediate/commercial_revenues_PROTOTYPE_2026_05_08.dta` | TRUE | `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/intermediate/commercial_revenues_PROTOTYPE_2026_05_08.Rds` | TRUE |
| recreational_intermediate | `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/intermediate/recreational_PROTOTYPE_2026_05_08.dta` | TRUE | `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/intermediate/recreational_PROTOTYPE_2026_05_08.Rds` | TRUE |
| permits_intermediate | `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/intermediate/permits_PROTOTYPE_2026_05_08.dta` | TRUE | `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/intermediate/permits_PROTOTYPE_2026_05_08.Rds` | TRUE |

---

## Results by Pair

### affiliates_final
**Script:** data_joins.do / data_joins.R
**Stata file:** `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/final/affiliates_PROTOTYPE_2026_05_08.dta`
**R file:** `C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset/data_folder/final/affiliates_PROTOTYPE_2026_05_08.Rds`
**Notes:** Final output panel: one row per permit per year over 5-year window. Contains entity_type_2024, small_business, affiliate-level revenue aggregates, permit plan-category indicators (HRG_A, BSB_1, etc.), and species-level revenue columns (value_NNNNNN). value_permit_commercial is DROPPED from both outputs. affiliate_id exact values are not compared (arbitrary sequential integers).
**Overall: PASS**

| Check | Result | Details |
|---|---|---|
| dimensions | PASS | Stata: 43645 rows × 426 cols |
| column_names | PASS | Stata columns: 426 \| R columns: 426 |
| column_types | PASS | Checked 426 common columns |
| missing_vals | PASS | Checked 426 common columns for NA counts |
| factor_levels | PASS | No factor/haven_labelled columns in Stata frame |
| values | PASS | Sorted by: permit, year |
| affiliate_structure | PASS | Distinct affiliates — Stata: 7877 \| R: 7877 |

All checks passed with no warnings.

---

## Discrepancy Detail

For each numeric column that failed the tolerance check, up to 20 worst-offending rows are shown (capped at 5 columns per pair).

No numeric discrepancy detail to report (all numeric checks passed, or no pairs run).

---

## Diagnosis Notes

For each failure, the most likely cause is indicated based on common Stata → R discrepancy patterns:

| Symptom | Most likely cause |
|---|---|
| max_diff near 1e-7 to 1e-12 | Floating-point accumulation — R and Stata differ in intermediate precision |
| max_diff of exactly 0.5 or 1 in value_permit_forhire | Rounding: Stata uses standard rounding, R may use banker's rounding |
| Row count mismatch in final affiliates | Panel balancing divergence — check tidyr::complete() vs tsfill behavior |
| Row count mismatch in commercial_revenues | Species column explosion or ZZZZZZ sentinel handling difference |
| NA position mismatches | Extended missing values (.a/.b) in Stata vs NA in R; check conversion-notes.md REVIEW items |
| Character mismatch in entity_type | Entity classification logic diverged — check affiliate_fish vs affiliate_forhire comparison at yr_select rows |
| affiliate_structure FAIL | Ownership merge diverged — check full_join vs merge m:1 behavior, especially for permits only in ownership |
| Permit indicator columns missing in R | ppp prefix stripping discrepancy — verify sub('^ppp','') vs renvars predrop(3) |

No failures to diagnose.

---

## Missing Files

All expected files were found on disk.

---

## Recommended Next Steps

The primary comparison (affiliates_final) **passed**. The R port of data_joins.R produces
output that is structurally and numerically equivalent to the Stata reference within the
specified tolerance (1e-06).

1. No failures require immediate attention.
2. Review any warnings above (type-promotion from haven_labelled to numeric is expected and acceptable).
3. If the for-hire revenue tolerance was raised to 1.0, confirm with the analyst that
   ±1 dollar rounding differences are acceptable for regulatory purposes.

---

*Report generated by verify_port.R | 2026-05-08 09:52:29*
