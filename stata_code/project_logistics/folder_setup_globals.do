/*
================================================================================
Script:      folder_setup_globals.do
Repository:  READ-SSB-Lee-RFAdataset
--------------------------------------------------------------------------------
Purpose:
  Sets every global macro and scalar needed by all downstream scripts: project
  paths, date-derived year-selection variables, CPI-U deflators, expenditure-
  per-angler scalars for for-hire revenue, and SBA small-business thresholds.
  Must be executed (or do'd) before any other script in the pipeline.

Pipeline Position:
  Step 0 — prerequisite for all other scripts. Not called by wrapper_extraction.do;
  must be run manually at session start or via profile.do (e.g., do "$RFAdataset").

Inputs:
  - $user global: set externally in profile.do; determines the project root path.
  - System date (c(current_date), $S_DATE): drives year-selection logic.

Outputs:
  - No files written.
  - Creates directories: ${my_datadir}/intermediate and ${my_datadir}/final.
  - Defines all globals and scalars consumed by extraction and processing scripts.

  
  
*/
version 15.1
scalar drop _all

#delimit ;

/* ----------------------------------------------------------------------------
 SECTION: User and Path Configuration
 Resolves $my_projdir based on the $user global set in profile.do.
Only the "minyangWin" user path is handled. Any user running on Windows
 or with a different username must add their own condition here, or set
$my_projdir externally before calling this script.
 ----------------------------------------------------------------------------
*/
if strmatch("$user","minyangWin"){;
global my_projdir "C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset";
};

/* setup data folder */
global my_datadir "${my_projdir}\data_folder";
global my_codedir "${my_projdir}\stata_code";

/* ----------------------------------------------------------------------------
SECTION: Date String and Vintage Label
 Constructs $today_date_string (CCYY_NN_DD) used as a filename suffix for
 all intermediate and final output files. $vintage_string starts equal to
 $today_date_string and gains the PROTOTYPE_ prefix if run before June 1
 (see the Prototype Flag section below).
 ----------------------------------------------------------------------------
*/
local date: display %td_CCYY_NN_DD date(c(current_date), "DMY");
global today_date_string = subinstr(trim("`date'"), " " , "_", .);
global vintage_string $today_date_string;


cap mkdir ${my_datadir}/intermediate;
cap mkdir ${my_datadir}/final;



/* PRELIMINARIES
----------------------------------------------------------------------------
SECTION: Year Selection Logic
 $yr_select is the primary analysis year (the most recently completed
 calendar year with complete data). The pipeline targets yr_select data but
 the permit portfolio snapshot is taken as of June 1, so the script shifts
 yr_select back by one additional year when run before June 1.
 $yr_permit_portfolio tracks which year's June 1 snapshot to use.

 Decision table:
   Month >= 6: yr_select = this_year-1, yr_permit_portfolio = this_year
   Month <  6: yr_select = this_year-2, yr_permit_portfolio = this_year-1
 ---------------------------------------------------------------------------- 
 */

/* Take care of Years and deflating */
/*These lines grab the ``correct year'', based on system date.
$yr_select is used to construct affiliated entities */

global this_year=year(date("$S_DATE","DMY"));
global this_month=month(date("$S_DATE","DMY"));
global this_day=day(date("$S_DATE","DMY"));

/* NOTE: $this_day is set but not used downstream. It was planned for a
* day-based conditional that was never implemented retained for future use.
*/

if $this_month>=6{;
	global yr_select=$this_year-1;         /* data for the just-completed calendar year*/
	global yr_permit_portfolio=$this_year; /*use the current year's June 1 permit snapshot*/
	};

else if $this_month<6{;
	global yr_select=$this_year-2;           /*shift back — June 1 snapshot not yet available*/
	global yr_permit_portfolio=$this_year-1;

};
global permit_date_pull "'06/01/${yr_permit_portfolio}'" ;
// The permit snapshot date is always June 1 only the year varies.

/* ----------------------------------------------------------------------------
 SECTION: CPI-U Deflators
 BLS CPI-U, all items (series CUUR0000SA0), HALF2 (second-half) annual values.
 Used in rec_exp extrapolation for years beyond 2022 when actual survey data
 are unavailable. Source: https://data.bls.gov/timeseries/CUUR0000SA0
 Update annually with the published HALF2 value.
----------------------------------------------------------------------------
Rec expenditures per angler and CPI for adjusting from the 2011 expenditure survey
*/
scalar C2010=218.056; // HARD-CODED: BLS CPI-U HALF2 2010 update series annually
scalar C2011=224.939; // HARD-CODED: BLS CPI-U HALF2 2011
scalar C2012=229.594; // HARD-CODED: BLS CPI-U HALF2 2012
scalar C2013=232.957; // HARD-CODED: BLS CPI-U HALF2 2013
scalar C2014=237.088; // HARD-CODED: BLS CPI-U HALF2 2014
scalar C2015=237.739; // HARD-CODED: BLS CPI-U HALF2 2015
scalar C2016=241.237; // HARD-CODED: BLS CPI-U HALF2 2016
scalar C2017=246.163; // HARD-CODED: BLS CPI-U HALF2 2017
scalar C2018=252.125; // HARD-CODED: BLS CPI-U HALF2 2018
scalar C2019=256.903; // HARD-CODED: BLS CPI-U HALF2 2019
scalar C2020=260.065; // HARD-CODED: BLS CPI-U HALF2 2020
scalar C2021=275.703; // HARD-CODED: BLS CPI-U HALF2 2021
scalar C2022=296.963; // HARD-CODED: BLS CPI-U HALF2 2022
scalar C2023=306.996; // HARD-CODED: BLS CPI-U HALF2 2023
scalar C2024=315.233; // HARD-CODED: BLS CPI-U HALF2 2024
scalar C2025=324;
/* manual update needed here, giant placeholders will produce odd results, which is better than a silent fail */
scalar C2026=1000000; // SENTINEL: intentionally extreme — replace with actual BLS value before running in 2027

/* ----------------------------------------------------------------------------
 SECTION: Expenditure-Per-Angler Scalars (rec_exp)
 rec_exp2010-2022 are direct survey values from Scott (documentation/
 input_data_docs/For-Hire_Fee.xlsx, DataSet2 sheet). Values represent dollars
 per angler per trip for for-hire recreational fishing.
 rec_exp2023 onward are CPI-extrapolated from the 2022 survey base value.
 These scalars are consumed by 03_for_hire_revenues.do.
 ----------------------------------------------------------------------------*/

/* Switch over to using data from Scott for the rec expenditures.  See the the DataSet2 sheet of For-Hire_Fee.xlsx spreadsheet in the documentation*/
scalar rec_exp2010 = 103.56; // HARD-CODED: survey value (For-Hire_Fee.xlsx DataSet2)
scalar rec_exp2011 = 113.44; // HARD-CODED: survey value
scalar rec_exp2012 = 116.15; // HARD-CODED: survey value
scalar rec_exp2013 = 118.86; // HARD-CODED: survey value
scalar rec_exp2014 = 121.57; // HARD-CODED: survey value
scalar rec_exp2015 = 124.28; // HARD-CODED: survey value
scalar rec_exp2016 = 126.99; // HARD-CODED: survey value
scalar rec_exp2017 = 129.69; // HARD-CODED: survey value
scalar rec_exp2018 = 132.40; // HARD-CODED: survey value
scalar rec_exp2019 = 135.11; // HARD-CODED: survey value
scalar rec_exp2020=137.82;   // HARD-CODED: survey value
scalar rec_exp2021=140.53;   // HARD-CODED: survey value
scalar rec_exp2022=143.24;   // HARD-CODED: survey value (most recent actual survey observation)

/*rec_exp2023+ are approximations via CPI extrapolation from the 2022 survey base.
Formula: rec_exp_YYYY = rec_exp2022 * C_YYYY / C2022

*/
scalar rec_exp2023=round(rec_exp2022*C2023/C2022, .01);
scalar rec_exp2024=round(rec_exp2022*C2024/C2022, .01);
scalar rec_exp2025=round(rec_exp2022*C2025/C2022, .01);
scalar rec_exp2026=round(rec_exp2022*C2026/C2022, .01);

/*
WARNING: rec_exp2026 is computed from C2026=1,000,000 (sentinel), producing
 a wildly inflated value. When the pipeline is run in 2027 (yr_select=2026),
for-hire revenue for 2026 will be obviously wrong. Replace C2026 with the
actual BLS HALF2 value before that run.

----------------------------------------------------------------------------
 SECTION: SBA Small-Business Size Standards
 The historical 2015 standards (80 FR 249) are preserved in the comment below
 for reference but are NOT active code.
 ----------------------------------------------------------------------------
*/

global sba_comm=11000000;
/* The 2015 size standards for Small Businesses  - 80FR249. Page 81194. Preserved here for historical interest
global sba_forhire=7500000;
*/

/*      84 FR 34261 changed the for-hire standard as of July 2019
https://www.federalregister.gov/documents/2019/07/18/2019-14980/small-business-size-standards-adjustment-of-monetary-based-size-standards-for-inflation
*/
global sba_forhire=8000000;

/*
 ----------------------------------------------------------------------------
 SECTION: Prototype Flag
 If run before June 1, prepends "PROTOTYPE_" to $vintage_string so all output
 filenames are clearly marked as preliminary data.
 REFACTOR CANDIDATE: similar pre-June-1 check appears in wrapper_extraction.do
 and data_joins.do. Consider extracting to a reusable program/subroutine.
 ----------------------------------------------------------------------------
*/
if $this_month<6{;
    di "Today is"  %td_CCYY_NN_DD date(c(current_date), "DMY");
    di "It is before the Jun 1 permit cutoff, so this data is preliminary";
	global vintage_string PROTOTYPE_$today_date_string ;

};







