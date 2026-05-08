/*
================================================================================
Script:      data_joins.do
Repository:  READ-SSB-Lee-RFAdataset
--------------------------------------------------------------------------------
Purpose:
  Central processing script. Merges commercial revenues, for-hire revenues,
  ownership, and permit portfolio data into a single balanced panel dataset.
  Fills in missing affiliate IDs, constructs affiliate-level revenue aggregates,
  classifies entities by industry type (FISHING/FORHIRE/NO_REV), determines
  small/large business status using 5-year average revenues vs. SBA thresholds,
  validates the output with assertion checks, and exports the final dataset in
  five formats.

Pipeline Position:
  Step 1e of the pipeline — central processing.

Inputs:
  - ${my_datadir}/intermediate/commercial_revenues_${vintage_string}.dta
  - ${my_datadir}/intermediate/recreational_${vintage_string}.dta
  - ${my_datadir}/intermediate/ownership_${vintage_string}.dta
  - ${my_datadir}/intermediate/permits_${vintage_string}.dta

Outputs:
  - ${my_datadir}/final/affiliates_condensed_${vintage_string}.xlsx
  - ${my_datadir}/final/affiliates_${vintage_string}.xlsx
  - ${my_datadir}/final/affiliates_${vintage_string}.dta
  - ${my_datadir}/final/affiliates_${vintage_string}.sas7bdat  (via Stat/Transfer)
  - ${my_datadir}/final/affiliates_${vintage_string}.Rdata     (via Stat/Transfer)

Key Macros Required:
  - $my_datadir, $vintage_string, $yr_select
  - $sba_forhire : for-hire SBA threshold (set by folder_setup_globals.do)
  - $sba_comm    : commercial SBA threshold — NOTE: this is commented out in
                   folder_setup_globals.do and may be undefined. Verify before run.
  - $this_month  : for the preliminary-data warning
  - $stattransfer : path to Stat/Transfer executable; SAS/R exports silently
                    fail if undefined

SQL Connections:
  None

Notes:
  - Two pause; commands (lines 81 and 190) halt execution in interactive Stata
    and will freeze batch/non-interactive runs indefinitely. You can just set pause off.
  - $stattransfer shell calls use !, which does not propagate OS-level errors
    back to Stata. If Stat/Transfer is absent, SAS and R files are silently
    not created.
  - local myplans is defined as empty. To include permit category indicators in
    the condensed export, add variable names (e.g., "HRG_A HRG_B") to that local.

================================================================================
*/

#delimit ;



/*---------------------------------------------------------------------------
 SECTION: Merge Commercial and For-Hire Revenues
 Starts with the commercial revenue dataset (wide, one row per permit-year).
 Merges in for-hire revenue 1:1 on permit and year year. _merge is dropped because
 unmatched rows on both sides are legitimate: commercial-only permits have no
 for-hire record and vice versa. Revenue zeros are filled in later.
---------------------------------------------------------------------------
*/

/* merge commercial to for-hire */

use ${my_datadir}/intermediate/commercial_revenues_${vintage_string}.dta, clear;
merge 1:1 permit year using  ${my_datadir}/intermediate/recreational_${vintage_string}.dta;
drop _merge;

/*---------------------------------------------------------------------------
 SECTION: Merge Ownership
 Merges affiliate_id from the ownership dataset m:1 on permit (not permit-year)
 because the ownership data holds only $yr_select ownership.

_merge=2 indicates there was a firm in the $yr_select that did not have any revenues.
We need to keep these in the dataset
---------------------------------------------------------------------------
*/

/*3. Join revenues data to affiliates (ownership data). */
merge m:1 permit using ${my_datadir}/intermediate/ownership_${vintage_string}.dta;



/* SECTION: Panel Balancing and Ownership Gap Fill
 tsset/tsfill creates a fully balanced panel across all permit-year combinations.
 Newly created rows from tsfill have missing ownership variables; the foreach
 and bysort blocks propagate the nearest known values within each permit's
 time series. _merge from the ownership step is retained temporarily to
 flag permits with no ownership records at all.
---------------------------------------------------------------------------
*/



/*
I need to fill the affiliate_id for any semi-matches.  These are
Permits that only show up once
	These are difficult, because they could have 1-2 years of revenue and may not be active in the most recent year
*/
tsset permit year;
tsfill, full;

sort permit (affiliate_id);

// Propagate person_id values to tsfill-created rows within each permit.

foreach var of varlist person_id*{;
	bysort permit (affiliate_id) : replace `var'=`var'[1] if `var'==. & affiliate_id==.;
};
bysort permit (affiliate_id) : replace affiliate_id=affiliate_id[1] if affiliate_id==.;

bysort permit (_merge): gen any_miss=_merge==1;
bysort permit: gen sum_any_miss=sum(any_miss);

/*
_merge==1 there are no owner_ids. We need to create a distinct affiliation id for each of these.  I will use the permit number.
_merge==2 there were no landings.  Need to tsset, then fill  so that value==0.  We'll do this at Checkpoint 100
_merge==3. There is a match between affiliation and revenue dataset.  Nothing to do.
*/

display "check5";
* Permits with no ownership match use the permit number as their affiliate_id,
* ensuring each is a unique singleton affiliation rather than grouped with others.
replace affiliate_id=permit if sum_any_miss>=1;
drop _merge sum_any_miss any_miss;

/*---------------------------------------------------------------------------
 SECTION: Merge Permit Portfolio
 Merges in plan-category indicators 1:1 on permit-year. Permits with no
 revenue or ownership but with a valid federal permit appear only in this
 dataset (_merge==2) and receive affiliate_id=permit.
 Missing permit category indicators and revenue variables are filled with 0
 after the merge.
---------------------------------------------------------------------------
*/

/* join permit data back to dataset. There are apparently some permits with no ownership info or landings, but permits.  */

merge 1:1 permit year using ${my_datadir}/intermediate/permits_${vintage_string}.dta;
display "check5";
replace affiliate_id=permit if affiliate_id==.; // permits with no revenue or ownership get singleton affiliations



/*This join is messy. All permit-years in the CFDBS-ownership data that do not have any Federal permit (_merge=1).
	These can be filled in with 0's
	There are also federal permits with no revenues (_merge=2).

	This is fixed at checkpoint 101.

ppp_* are permit category indicators: 0 means the permit was not held in that plan-category.
*/
quietly foreach var of varlist ppp* {;
	replace `var'=0 if `var'==.;
};

/* Revenue zeros: permits with no commercial or for-hire activity in a year have value=0.
 fill in zeros for missing values of revenue */
quietly foreach var of varlist value* {;
	replace `var'=0 if `var'==.;
};

pause;
/*---------------------------------------------------------------------------
SECTION: Affiliate-Level Revenue Aggregation
 Constructs affiliate-level totals by summing across all permits in each
 affiliate-year group. For single-permit affiliates the affiliate variables
 equal the permit variables. Checks first that no permit has two affiliate_ids.
---------------------------------------------------------------------------
*/


/* 4.  Construct Affiliate level gross revenues, gross revenues by "category", and make a determination of "SMALL" and "LARGE" */
/*fill in missing affiliates with permit numbers.  This will be for vessels with no ownership information but that had landings or owned a permit*/

/* it should be impossible for a vp_num to have 2 affiliate_id's in a year.  Check this and break the program if there are vp_nums with 2 affiliated_ids. */
tempvar mytt;
duplicates tag permit affiliate_id year, gen(`mytt');
assert `mytt'==0;

gen value_permit=value_permit_commercial+value_permit_forhire;

/*---------------------------------------------------------------------------
 SECTION: Affiliate ID Gap Fill
 Three-pass propagation handles permits whose affiliate_id is missing for some
 years: last-known propagated backward, first-known forward, second-position
 as tiebreaker. Final fallback uses permit number.
---------------------------------------------------------------------------
*/

/* fill in missing affiliate_ids : last, first, middle */
bysort permit (year): replace affiliate_id=affiliate_id[_N] if affiliate_id==.; // last known value → backward fill
bysort permit (year): replace affiliate_id=affiliate_id[1] if affiliate_id==.;  // first known value → forward fill
bysort permit (year): replace affiliate_id=affiliate_id[2] if affiliate_id==.;  // second position as tiebreaker
replace affiliate_id=permit if affiliate_id==.;                                  // final fallback
assert affiliate_id~=.;


order affiliate_id permit year value_permit value_permit_forhire value_permit_commercial;
sort affiliate_id permit year;
quietly compress;

/*construct affililate level revenues
NOTE: For affiliate_ids with 1 permit every year, the "affiliate" variables are identical to the "value_permit" variables.
For affiliate_ids with more than 1 permit in a year, there are "multiple" duplicated entries for the "affiliate" variables.
*/

bysort affiliate_id year: egen affiliate_total=sum(value_permit);
bysort affiliate_id year: egen affiliate_fish=sum(value_permit_commercial);
bysort affiliate_id year: egen affiliate_forhire=sum(value_permit_forhire);

order affiliate_total affiliate_f*, after(year);

format affiliate* value* %16.0gc;
sort permit year;

/*---------------------------------------------------------------------------
 SECTION: Entity Type Classification
 Classifies each affiliate as FORHIRE (for-hire revenue >= commercial),
 FISHING (commercial revenue > for-hire), or NO_REV (both zero).
 Classification is first assigned to all years using each year's revenue, then
 overwritten with the $yr_select value and propagated backward, so entity_type
 is constant across all panel years for each affiliate.
---------------------------------------------------------------------------
*/

display "check6";
/* Classify entities based on revenues
a.  Classify for all years
b.  overwrite with the most-recent year*/

gen str9 entity_type_$yr_select="FORHIRE";
replace entity_type_$yr_select="FISHING" if affiliate_fish>affiliate_forhire;
replace entity_type_$yr_select="NO_REV" if affiliate_fish==0 & affiliate_forhire==0;
replace entity_type_$yr_select="" if year~=$yr_select;
bysort affiliate_id (year): replace entity_type_$yr_select=entity_type_$yr_select[_N] if strmatch(entity_type_$yr_select,"");
// Propagates the current-year classification to all prior years in the panel.
/*ensure all entities are classified*/
assert strmatch(entity_type_$yr_select,"")==0;

/*---------------------------------------------------------------------------
 SECTION: Small/Large Business Classification
 Computes 5-year average revenue per affiliate, weighting by permit count to
 avoid double-counting multi-permit affiliates. Applies the SBA threshold
 appropriate to the entity's type. small_business=1 (small), =0 (large).
---------------------------------------------------------------------------
*/


clonevar value_dum=value_permit;


/* get the right number of observations */
gen counter=1;
bysort affiliate_id year (permit): replace counter=0 if _n>1;
bysort affiliate_id: egen affiliate_counter=sum(counter);

bysort affiliate_id: egen affiliate_bar=sum(value_dum);


/* AVERAGE REVENUE */
replace affiliate_bar=affiliate_bar/affiliate_counter;

gen small_business=1;
replace small_business=0 if strmatch(entity_type_$yr_select,"FORHIRE") & affiliate_bar>=$sba_forhire;
replace small_business=0 if strmatch(entity_type_$yr_select,"FISHING") & affiliate_bar>=$sba_comm;

display "check7";



sort affiliate_id year permit;
drop value_permit_commercial;
order affiliate_id year entity_type_$yr_select small_business permit affiliate_total affiliate_fish affiliate_forhire value_permit*;
quietly compress;
display "check8";

/* logic check: was everything classified properly?*/
gen check=0;
replace check=1 if strmatch(entity_type_$yr_select,"FISHING")==1 & small_business==1 & affiliate_bar>$sba_comm;
replace check=1 if strmatch(entity_type_$yr_select,"FORHIRE")==1 & small_business==1 & affiliate_bar>$sba_forhire;
assert check==0;
drop check;
drop affiliate_bar;

/* logic check: did you update the prices/expenditures of for hire fishing
These asserts will "break" if the mean of affiliate_forhire is zero, if it is "missing", if there are no entries.
This might happen if there is either a zero price or missing price for for-hire
*/

quietly summ affiliate_forhire;
scalar NN=r(N);
scalar pp=r(mean);
assert scalar(pp)~=0;
assert scalar(pp)~=.;
assert scalar(NN)~=.;
assert scalar(NN)~=0;


/* checkpoint 101.*/
/* there are some missing variables in the permit types.  These aren't actually missing: they should be zeros */


pause;
/*---------------------------------------------------------------------------
 SECTION: Permit Category Cleanup
 Fills any remaining missing ppp_* indicators with 0. Removes variable labels
 (uninformative at this stage). Strips the 3-character "ppp" prefix from all
 ppp_* variable names, leaving HRG_A, BSB_1, etc. in the final dataset.
---------------------------------------------------------------------------
*/

quietly foreach var of varlist ppp*{;
	replace `var'=0 if `var'==.;
	label var `var' ;
};
renvars ppp*, predrop(3); // strips the "ppp" prefix (3 chars); ppp_HRG_A becomes HRG_A




display "check9";

/*---------------------------------------------------------------------------
 SECTION: Permit Count and Panel Balance Assertions
 Generates count_permits per affiliate-year and verifies it is constant within
 each affiliate (a permit should not disappear from an affiliate mid-panel).
 The plan-category SD check verifies that each permit's category indicators
 do not vary across years (they are a snapshot and should be constant in this
 panel structure). The hard-coded plan prefixes cover all currently known NMFS
 plan categories; add new prefixes if the permit system expands.
---------------------------------------------------------------------------
*/

/*generate a variable that contains the count of distinct permits for each affiliate */
bysort affiliate_id year: gen count_permits=_N;
order count_permits, after(year);
bysort affiliate_id (count_permits): gen diff=count_permits[1] !=count_permits[_N];
assert diff==0;
drop diff;


/* HARD-CODED: plan-category prefixes; would be better to get them from the data? Or from the valid_fishery table. */
foreach var of varlist BLU_* BSB_* DOG_* FLS_* HMS_* HRG_* LGC_* LO_* MNK_* MUL_* OQ_* RCB_* SCP_* SC_* SF_* SKT_* SMB_* TLF_* {;
	bysort permit: egen problem_`var'=sd(`var');
	qui summ problem_`var';
		if r(mean)==0{;
			di "permit `var' is ok";
			drop problem_`var';
		};
		else{;
			di "permit `var' is has a problem";
		};
};



drop __*;
sort affiliate_id year permit ;

/* assert that every affiliate_id is in every year*/
preserve;
keep affiliate_id year;
duplicates drop;
tsset affiliate_id year;
assert strmatch("`r(balanced)'","strongly balanced");
restore;

/* assert that I see every permit in every year */
tsset permit year;
assert "`r(balanced)'"=="strongly balanced";


compress;

cap drop value_dum;
cap drop _merge;
cap drop counter;
cap drop affiliate_counter;

/* ----------------------------------------------------------------------------
 SECTION: Export Final Dataset
 Condensed Excel export: a subset of columns; `myplans' is currently empty.
   To include permit category indicators (e.g., HRG_A HRG_B), add their names
   to the local myplans definition below.
 Full Excel export: all columns.
 Stata .dta: saveold version(12) for backward compatibility.
 SAS/R exports via Stat/Transfer: silent failure if $stattransfer is undefined.
 ----------------------------------------------------------------------------
*/
sort affiliate_id year permit;
/* add a few plans to local myplans if you want to export any indicator variables */
local myplans ;

export excel affiliate_id year count_permits entity_type_$yr_select small_business permit affiliate_total affiliate_fish affiliate_forhire value_permit*  `myplans' using  "${my_datadir}/final/affiliates_condensed_${vintage_string}.xlsx", firstrow(variables) replace;
export excel using "${my_datadir}/final/affiliates_${vintage_string}.xlsx", firstrow(variables) replace;


save "${my_datadir}/final/affiliates_${vintage_string}.dta", replace;

/* if your system is aware of stat-transfer, this will automatically create sas and Rdata datasets
WARNING: ! does not propagate OS errors to Stata. If $stattransfer is
 undefined or not installed, these files are silently not created.
*/
! "$stattransfer" "${my_datadir}/final/affiliates_${vintage_string}.dta"  "${my_datadir}/final/affiliates_${vintage_string}.sas7bdat" -y;
! "$stattransfer" "${my_datadir}/final/affiliates_${vintage_string}.dta"  "${my_datadir}/final/affiliates_${vintage_string}.Rdata" -y;



if $this_month<6{;
    di "Today is"  %td_CCYY_NN_DD date(c(current_date), "DMY");
    di "It is before the Jun 1 permit cutoff, so this data is preliminary";
};
