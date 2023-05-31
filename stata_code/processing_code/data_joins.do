
/* Min-Yang.Lee@noaa.gov */

/* Objective: This code is used to

Join revenues data to affiliates (ownership data).
Join to the PLAN-CAT data from vps_fishery_ner

*/
#delimit ; 


/* merge commercial to for-hire */

use ${my_datadir}/intermediate/commercial_revenues.dta, replace;
merge 1:1 permit year using  ${my_datadir}/intermediate/recreational.dta;
drop _merge;

/*3. Join revenues data to affiliates (ownership data). */
merge m:1 permit using ${my_datadir}/intermediate/ownership.dta;






/*
I need to fill the affiliate_id for any semi-matches.  These are 
Permits that only show up once
	These are difficult, because they could have 1-2 years of revenue and may not be active in the most recent year
*/
tsset permit year;
tsfill, full;

sort permit (affiliate_id);

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
replace affiliate_id=permit if sum_any_miss>=1;
drop _merge sum_any_miss any_miss;



/* join permit data back to dataset. There are apparently some permits with no ownership info or landings, but permits.  */

merge 1:1 permit year using ${my_datadir}/intermediate/permits.dta;
display "check5";
replace affiliate_id=permit if affiliate_id==.;



/*This join is messy. All permit-years in the CFDBS-ownership data that do not have any Federal permit (_merge=1).
	These can be filled in with 0's
	There are also federal permits with no revenues (_merge=2).

	This is fixed at checkpoint 101.
	*/

quietly foreach var of varlist ppp* {;
	replace `var'=0 if `var'==.;
};

/* fill in zeros for missing values of revenue */
quietly foreach var of varlist value* {;
	replace `var'=0 if `var'==.;
};

pause;


/* 4.  Construct Affiliate level gross revenues, gross revenues by "category", and make a determination of "SMALL" and "LARGE" */
/*fill in missing affiliates with permit numbers.  This will be for vessels with no ownership information but that had landings or owned a permit*/

/* it should be impossible for a vp_num to have 2 affiliate_id's in a year.  Check this and break the program if there are vp_nums with 2 affiliated_ids. */
tempvar mytt;
duplicates tag permit affiliate_id year, gen(`mytt');
assert `mytt'==0;





/*Aggregate revenues to shellfish, finfish, commercial, and total levels
Shellfish are nespp3=700 to nespp3=806, plus nespp3=834*/
/* distinguishing between finfish and shellfish isn't necessary anymore, but we'll leave it anyway */

cap gen value806=0;
order value806, after(value805);
egen value_permit_shellfish=rowtotal(value700-value806);
replace value_permit_shellfish=value_permit_shellfish+value834;
egen value_permit_commercial=rowtotal(value001-value834);
gen value_permit_finfish=value_permit_commercial-value_permit_shellfish;
gen value_permit=value_permit_commercial+value_permit_forhire;

/* fill in missing affiliate_ids : last, first, middle */
bysort permit (year): replace affiliate_id=affiliate_id[_N] if affiliate_id==.;
bysort permit (year): replace affiliate_id=affiliate_id[1] if affiliate_id==.;
bysort permit (year): replace affiliate_id=affiliate_id[2] if affiliate_id==.;
replace affiliate_id=permit if affiliate_id==.;
assert affiliate_id~=.;


order affiliate_id permit year value_permit value_permit_finfish value_permit_shellfish value_permit_forhire value_permit_commercial;
sort affiliate_id permit year;
quietly compress;

/*construct affililate level revenues
NOTE: For affiliate_ids with 1 permit every year, the "affiliate" variables are identical to the "value_permit" variables.
For affiliate_ids with more than 1 permit in a year, there are "multiple" duplicated entries for the "affiliate" variables.
*/

bysort affiliate_id year: egen affiliate_total=sum(value_permit);
bysort affiliate_id year: egen affiliate_shellfish=sum(value_permit_shell);
bysort affiliate_id year: egen affiliate_finfish=sum(value_permit_finfish);

gen affiliate_fish=affiliate_shellfish + affiliate_finfish;
bysort affiliate_id year: egen affiliate_forhire=sum(value_permit_forhire);
drop affiliate_shellfish affiliate_finfish value_permit_shellfish value_permit_finfish;
order affiliate_t affiliate_f*, after(year);

format affiliate_total-value834 %16.0gc;
sort permit year;


display "check6";
/* Classify entities based on revenues
a.  Classify for all years
b.  overwrite with the most-recent year*/

gen str9 entity_type_$yr_select="FORHIRE";
replace entity_type_$yr_select="FISHING" if affiliate_fish>affiliate_forhire;
replace entity_type_$yr_select="NO_REV" if affiliate_fish==0 & affiliate_forhire==0;
replace entity_type_$yr_select="" if year~=$yr_select;
bysort affiliate_id (year): replace entity_type_$yr_select=entity_type_$yr_select[_N] if strmatch(entity_type_$yr_select,"");
/*ensure all entities are classified*/
assert strmatch(entity_type_$yr_select,"")==0;

/* classify affiliate_id as small or large based on 5-year average of TOTAL revenues. Use the appropriate size standard.
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
order affiliate_id year entity_type small_business permit affiliate_total affiliate_fish affiliate_forhire value_permit*;
quietly compress;
display "check8";

/* logic check: was everything classified properly?*/
gen check=0;
replace check=1 if strmatch(entity,"FISHING")==1 & small==1 & affiliate_bar>$sba_comm;
replace check=1 if strmatch(entity,"FORHIRE")==1 & small==1 & affiliate_bar>$sba_forhire;
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

quietly foreach var of varlist ppp*{;
	replace `var'=0 if `var'==.;
	label var `var' ;
};
renvars ppp*, predrop(3);




display "check9";

/*generate a variable that contains the count of distinct permits for each affiliate */
bysort affiliate_id year: gen count_permits=_N;
order count_permits, after(year);
bysort affiliate_id (count_permits): gen diff=count_permits[1] !=count_permits[_N];
assert diff==0;
drop diff;


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
compress;

export excel affiliate_id year count_permits entity_type_$yr_select small_business permit affiliate_total affiliate_fish affiliate_forhire value_permit*  `myplans' using  "${my_datadir}/final/affiliates_condensed_${vintage_string}.xlsx", firstrow(variables) replace;
export excel using "${my_datadir}/final/affiliates_${vintage_string}.xlsx", firstrow(variables) replace;


saveold "${my_datadir}/final/affiliates_${vintage_string}.dta", replace version(12);

/* if your system is aware of stat-transfer, this will automatically create sas and Rdata datasets
*/

! "$stat_transfer" "${my_datadir}/final/affiliates_${vintage_string}.dta"  "${my_datadir}/final/affiliates_${vintage_string}.sas7bdat" -y;
! "$stat_transfer" "${my_datadir}/final/affiliates_${vintage_string}.dta"  "${my_datadir}/final/affiliates_${vintage_string}.Rdata" -y;




