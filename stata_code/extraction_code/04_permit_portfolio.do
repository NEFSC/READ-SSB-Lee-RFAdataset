/*
================================================================================
Script:      04_permit_portfolio.do
Repository:  READ-SSB-Lee-RFAdataset
--------------------------------------------------------------------------------
Purpose:
  Extracts permit plan-category holdings for all permits active as of June 1
  of $yr_permit_portfolio. Reshapes to wide so each row is a permit with binary
  indicator columns (ppp_PLAN_CAT = 1 if held, 0 if not). Expands to 5 rows
  per permit to match the 5-year panel structure of the revenue datasets,
  enabling a clean 1:1 join in data_joins.do.

Pipeline Position:
  Step 1d of extraction — called last by wrapper_extraction.do.
  Produces the permit portfolio intermediate file consumed by data_joins.do.

Inputs:
  - Oracle DB via $myNEFSC_USERS_conn:
    * NEFSC_GARFO.PERMIT_VPS_FISHERY_NER : permit applications with plan/category
      codes and effective date ranges

Outputs:
  - ${my_datadir}/intermediate/permits_${vintage_string}.dta
    Columns: permit, year, one ppp_PLAN_CAT indicator per plan-category combination
    (e.g., ppp_HRG_A, ppp_BSB_1). The "ppp_" prefix is stripped by renvars in
    data_joins.do, yielding HRG_A, BSB_1, etc. in the final output.

Key Macros Required:
  - $permit_date_pull    : June 1 snapshot date string, e.g. '06/01/2024'
                           (set by folder_setup_globals.do)
  - $yr_select           : used to set the year for the expanded panel
  - $myNEFSC_USERS_conn  : ODBC connection string for NEFSC_USERS
  - $my_datadir, $vintage_string

SQL Connections:
  - DSN: $myNEFSC_USERS_conn
  - Tables: NEFSC_GARFO.PERMIT_VPS_FISHERY_NER

Notes:
  - The June 1 snapshot selects max(ap_num) per vp_num to get the most recent
    permit application whose effective date range spans June 1. Permit portfolio
    is a point-in-time snapshot, not a history across the 5-year window.
  - gen str10 plancat assumes plan + "_" + cat fits in 10 characters. If Oracle
    returns plan or cat values longer than expected, silent truncation occurs. Plans are 3
	and cats are usual 2, so this should be fine. 																			   								 
  - expand 5 creates 5 identical rows per permit; bysort permit: replace year
    then assigns years yr_select, yr_select-1, ..., yr_select-4.
================================================================================
*/  
/* Extract permit data for year "$yr_select" */

#delimit;
clear;
/* SQL QUERY — DSN: $myNEFSC_USERS_conn
 Purpose: Retrieve plan-category combinations for all permits active on the
          June 1 snapshot date ($permit_date_pull). Uses max(ap_num) per
          vp_num to select the single most recent permit application whose
          effective date range spans June 1, giving one record per vessel.
 Tables:  NEFSC_GARFO.PERMIT_VPS_FISHERY_NER
 Note:    $permit_date_pull is interpolated; resolves to e.g. '06/01/2024'.
          Oracle to_date() converts this string to a date for comparison.
*/
		  odbc load,  exec("select vp_num, plan, cat from NEFSC_GARFO.PERMIT_VPS_FISHERY_NER
		where ap_num in
			(select max(ap_num) as ap_num from NEFSC_GARFO.PERMIT_VPS_FISHERY_NER where
		to_date(${permit_date_pull},'MM/DD/YYYY') between trunc(start_date,'DD') and trunc(end_date,'DD')
		 group by vp_num)
		 ;")  $myNEFSC_USERS_conn;




/* SECTION: Plan-Category Indicator Construction
 Concatenates the plan and cat columns into a single plancat string
 (e.g., "HRG_A"), deduplicates any redundant rows, adds a constant ppp=1
 indicator, then reshapes to wide. Each unique plancat becomes a ppp_PLAN_CAT
 column with value 1 for that permit.
*/

gen str10 plancat=plan+"_"+cat;
compress plancat;
drop plan cat;
/* there's a few 'duplicated' entries */
duplicates drop;
gen ppp=1;
reshape wide ppp, i(vp_num) j(plancat) string;
rename vp_num permit;
sort permit;

/* SECTION: Panel Expansion to 5 Years
 expand 5 creates 5 copies of each permit row. The bysort replace then
 assigns a different year to each copy, covering yr_select down to yr_select-4.
 This matches the 5-year window structure of the commercial and for-hire
 revenue datasets so that data_joins.do can merge 1:1 on permit-year.
 this probably a little over the top, since I could do a m:1 join later on 
*/

expand 5;
gen year=$yr_select;
bysort permit: replace year=year-_n+1;
foreach var of varlist ppp*{;
	replace `var'=0 if `var'==.;
};
order permit year;
sort permit year;

save ${my_datadir}/intermediate/permits_${vintage_string}.dta, replace;





