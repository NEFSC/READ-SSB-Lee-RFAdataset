/*
================================================================================
Script:      02_commercial_revenues.do
Repository:  READ-SSB-Lee-RFAdataset
--------------------------------------------------------------------------------
Purpose:
  Pulls commercial landing values from CAMS (Catch Accounting and Monitoring
  System) for the 5-year window $firstyr to $yr_select, aggregated by permit,
  year, and ITIS TSN (species code). Reshapes to wide so each row is a
  permit-year with one value_NNNNNN column per species present in the data.

Pipeline Position:
  Step 1b of extraction — called second by wrapper_extraction.do.
  Consumes $firstyr set by wrapper_extraction.do (not defined in this script).
  Produces the commercial revenue intermediate file consumed by data_joins.do.

Inputs:
  - Oracle DB via $myNEFSC_USERS_conn:
    * cams_land (full name: cams_garfo.cams_land) : commercial landings with
      ITIS TSN species codes and dollar values

Outputs:
  - ${my_datadir}/intermediate/commercial_revenues_${vintage_string}.dta
    Columns: permit, year, value_permit_commercial, value_NNNNNN per species

Key Macros Required:
  - $firstyr            : start year of the 5-year window (set in wrapper_extraction.do)
  - $yr_select          : end year of the window
  - $myNEFSC_USERS_conn : ODBC connection string for NEFSC_USERS
  - $my_datadir, $vintage_string

SQL Connections:
  - DSN: $myNEFSC_USERS_conn
  - Tables: cams_land (schema: cams_nefsc; resolved by Oracle session search path)

Notes:
  - renvars, lower normalizes Oracle column names (returned uppercase) to
    lowercase, matching Stata naming conventions used downstream.
  - Species are identified by ITIS TSN codes (not NESPP3/4). The pipeline
    switched to CAMS_LAND and ITIS codes from NESPP3/4 codes in the prior year.
    The variable name suffix for each species is its ITIS TSN integer
    (e.g., value_161722 for Atlantic herring).
  - The ZZZZZZ sentinel ITIS TSN carries the permit-level total through the
    reshape step and is then renamed to value_permit_commercial.
================================================================================
*/

/***************************************************
2a.  Commercial Landings and revenues from Last 5 years
***************************************************/
#delimit ;

	clear;

/* SQL QUERY — DSN: $myNEFSC_USERS_conn
 Purpose: Retrieve 5-year commercial landing dollar values from CAMS, summed
          to the permit-year-species level. NVL converts NULL to 0. Filters
          out NULL and zero ITIS TSN codes which indicate non-species records.
 Tables:  cams_garfo.cams_land
 Note:    $firstyr and $yr_select are interpolated into the BETWEEN clause.
*/
/* Pull data from CAMS, group by permit, year and species */
odbc load,  exec("select permit, year, sum(nvl(value,0)) as value, itis_tsn from cams_garfo.cams_land cl where
		cl.year between $firstyr and $yr_select and itis_tsn is not NULL and itis_tsn<>0
        group by permit, year, itis_tsn;") $myNEFSC_USERS_conn;

/* ----------------------------------------------------------------------------
 SECTION: Cleanup and Administrative Permit Filter
 Converts permit and year to numeric. Removes five administrative/dummy permit
 codes that are not real vessels. Lowercases all column names to match
 downstream Stata naming conventions (Oracle returns uppercase).
 ----------------------------------------------------------------------------
*/
/* Minor bits of cleanup */
destring permit year, replace ;
// The five excluded codes are administrative dummy permits, not real vessels:

drop if permit==190998 | permit==290998 | permit==390998 | permit==490998 | permit==000000;
renvars, lower;     // Oracle returns uppercase column names; normalize to lowercase
compress;
display "check3";

/* ----------------------------------------------------------------------------
SECTION: Permit-Level Total and Wide Reshape
 Preserves the original long data, collapses to a permit-year total (summing
 across all species), tags it with a sentinel ITIS TSN "ZZZZZZ", and appends
 it back. After the reshape to wide (one column per species), ZZZZZZ becomes
 the total column and is renamed to value_permit_commercial.
 The sentinel sorts last alphabetically, so it stays distinct from species codes.
 ----------------------------------------------------------------------------
*/
rename value value_ ;

preserve;
collapse (sum) value_, by(permit year);
tempfile total;
gen itis_tsn="ZZZZZZ"; // sentinel code to carry the permit-level total through the reshape
save `total';
restore;
append using `total';


reshape wide value_, i(permit year) j(itis_tsn) string;
rename value_ZZZZZZ value_permit_commercial;
label var value_permit_commercial "value from commercial fishing";
foreach var of varlist value*{;
	replace `var'=0 if `var'==.;
};
sort permit year;
save ${my_datadir}/intermediate/commercial_revenues_${vintage_string}.dta, replace;


