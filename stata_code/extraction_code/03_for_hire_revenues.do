/*
================================================================================
Script:      03_for_hire_revenues.do
Repository:  READ-SSB-Lee-RFAdataset
--------------------------------------------------------------------------------
Purpose:
  Computes for-hire (charter/party boat) revenue at the permit-year level.
  Extracts angler counts from Vessel Trip Reports (VTR) for party (tripcatg=2)
  and charter (tripcatg=3) trips using handline gear (GEARCODE='HND'), then
  multiplies by an expenditure-per-angler scalar to produce an estimated
  dollar revenue per permit per year.

Pipeline Position:
  Step 1c of extraction — called third by wrapper_extraction.do.
  Depends on $firstyr set by wrapper_extraction.do.
  Produces the for-hire revenue intermediate file consumed by data_joins.do.

Inputs:
  - Oracle DB via $myNEFSC_USERS_conn:
    * NEFSC_GARFO.TRIP_REPORTS_DOCUMENT : VTR records (sailing date, trip
      category, angler count)
    * NEFSC_GARFO.TRIP_REPORTS_IMAGES   : gear records linked to trip documents

Outputs:
  - ${my_datadir}/intermediate/recreational_${vintage_string}.dta
    Columns: permit, year, anglers, value_permit_forhire

Key Macros Required:
  - $firstyr            : start year of the 5-year window (set in wrapper_extraction.do)
  - $yr_select          : end year of the window
  - $myNEFSC_USERS_conn : ODBC connection string for NEFSC_USERS
  - $my_datadir, $vintage_string
  - Scalars rec_expYYYY : dollars per angler per trip by year (folder_setup_globals.do)

SQL Connections:
  - DSN: $myNEFSC_USERS_conn
  - Tables: NEFSC_GARFO.TRIP_REPORTS_DOCUMENT, NEFSC_GARFO.TRIP_REPORTS_IMAGES

Notes:
  - Revenue is computed as anglers * rec_exp.
  - The GEARCODE='HND' (handline) filter is a deliberate choice
  - rec_exp scalars are defined through rec_exp2026 in folder_setup_globals.do.
    However, rec_exp2026 is computed from a sentinel CPI (1,000,000) and will
    produce obviously inflated results if $yr_select >= 2026. Replace C2026
    in folder_setup_globals.do with the actual BLS value before that run.
  -	A vessel may have revenue from both commerical sources and for-hire trips.

================================================================================
*/


#delimit ; 

clear;

/* SQL QUERY — DSN: $myNEFSC_USERS_conn
 Purpose: Sum angler counts by permit-year for party (tripcatg=2) and
          charter (tripcatg=3) trips that used handline gear (GEARCODE='HND').
          
          The GEARCODE filter is a methodological choice reflecting the MRIP
          The subquery on TRIP_REPORTS_IMAGES identifies trip document IDs
          with at least one handline gear record.
 Tables:  NEFSC_GARFO.TRIP_REPORTS_DOCUMENT, NEFSC_GARFO.TRIP_REPORTS_IMAGES
 Note:    $firstyr and $yr_select are interpolated into the BETWEEN clause.
*/
 odbc load,  exec("select VESSEL_PERMIT_NUM as permit, extract(YEAR FROM DATE_SAIL) as year,  sum(nvl(nanglers,0)) as anglers from NEFSC_GARFO.TRIP_REPORTS_DOCUMENT where 
	(tripcatg between 2 and 3) and 
	docid in (select distinct docid from NEFSC_GARFO.TRIP_REPORTS_IMAGES where GEARCODE='HND') and
	extract(YEAR FROM DATE_SAIL) BETWEEN $firstyr and $yr_select
	group by VESSEL_PERMIT_NUM, extract(YEAR FROM DATE_SAIL);") $myNEFSC_USERS_conn;
/* ----------------------------------------------------------------------------
 SECTION: Revenue Calculation
 Matches each observation's year to the corresponding rec_exp scalar from
 folder_setup_globals.do. Revenue = anglers * rec_exp, rounded to whole
 dollars. 
 ----------------------------------------------------------------------------
*/
gen rec_exp=.;
forvalues yr = $firstyr(1)$yr_select {;
		replace rec_exp=scalar(rec_exp`yr') if year==`yr';
 } ;
	
gen value_permit_forhire=round(anglers*rec_exp);
drop rec_exp;
sort permit year;
save ${my_datadir}/intermediate/recreational_${vintage_string}.dta, replace;



