
/* Min-Yang.Lee@noaa.gov */

/* Objective: This code is used to generate the "RFA" dataset. It does 6 things:
1.  Construct Affiliates
2.  Revenues:
	a. Pull out landings from CFDBS  from the last 3 years.
	b. Get SCOQ revenues from a SCOQ
	c.  Compute the for-hire revenue based on VESLOG
3. Join revenues data to affiliates (ownership data).
4.  Join to the PLAN-CAT data from vps_fishery_ner
5.  Construct Affiliate level gross revenues, gross revenues by "category", and make a determination of "SMALL" and "LARGE".  Fill in zeros.
6.  added "permits per affiliate_id"
You might need some user-written commands to run this code

You will also need access to some tables on sole
permit.vps_owner, permit.bus_own, permit.vps_fishery_ner
cfdbs.cfdersYYYY in the appropriate years
sfclam.sfoqpr
vtr.veslogYYYYt and vtr.veslogYYYYg

This code is a little janky - it would have been smarter to consolidate the data extraction steps, the "cleanup/rehsaping steps", and the joining steps into distinct blocks (good) or sub-files (better).

*/



/* PRELIMINARIES */
/* Set up folders and oracle connection*/

clear
version 15.1
scalar drop _all
pause off
pause on

#delimit ;
global stat_transfer "C:/Program Files/StatTransfer15-64/st.exe";


/* PRELIMINARIES */
/* Take care of Years and deflating */
/*These lines grab the ``correct year'', based on system date.
$yr_select is used to construct affiliated entities */

global this_year=year(date("$S_DATE","DMY"));
global this_month=month(date("$S_DATE","DMY"));
global this_day=day(date("$S_DATE","DMY"));


if $this_month>=6{;
	global yr_select=$this_year-1;
	global yr_permit_portfolio=$this_year;
	};

else if $this_month<6{;
	global yr_select=$this_year-2;
	global yr_permit_portfolio=$this_year-1;

};


/*Rec expenditures per angler and CPI for adjusting from the 2011 expenditure survey

 CPI Annual CUUR0000SA0
Looks like I'm using the HALF2 numbers since at least 2014.
*/
scalar C2010=218.056;
scalar C2011=224.939;
scalar C2012=229.594;
scalar C2013=232.957;
scalar C2014=237.088;
scalar C2015=237.739;
scalar C2016=241.237;
scalar C2017=246.163;
scalar C2018=252.125;
scalar C2019=256.903;
scalar C2020=260.065;

/*
scalar rec_exp2011=111;
scalar rec_exp2010=round(rec_exp2011*C2010/C2011, .01);
scalar rec_exp2012=round(rec_exp2011*C2012/C2011, .01);
scalar rec_exp2013=round(rec_exp2011*C2013/C2011, .01);
scalar rec_exp2014=round(rec_exp2011*C2014/C2011, .01);
scalar rec_exp2015=round(rec_exp2011*C2015/C2011, .01);
scalar rec_exp2016=round(rec_exp2011*C2016/C2011, .01);
scalar rec_exp2017=round(rec_exp2011*C2017/C2011, .01);
scalar rec_exp2018=round(rec_exp2011*C2018/C2011, .01);
scalar rec_exp2019=round(rec_exp2011*C2019/C2011, .01);
scalar rec_exp2020=round(rec_exp2011*C2020/C2011, .01);
*/

/* Switch over to using data from Scott for the rec expenditures.  See the the DataSet2 sheet of For-Hire_Fee.xlsx spreadsheet in the documentation*/


scalar rec_exp2010 = 103.56;
scalar rec_exp2011 = 113.44;
scalar rec_exp2012 = 116.15;
scalar rec_exp2013 = 118.86;
scalar rec_exp2014 = 121.57;
scalar rec_exp2015 = 124.28;
scalar rec_exp2016 = 126.99;
scalar rec_exp2017 = 129.69;
scalar rec_exp2018 = 132.40;
scalar rec_exp2019 = 135.11;
/* nothing for 2020 yet, so just adjust the 2019 by CPI */
scalar rec_exp2020=round(rec_exp2019*C2020/C2019, .01);



/* SBA size standards for-hire, finfish, and shellfish
Changes to reflect July 2014 changes
global sba_forhire=7000000;
global sba_finfish=19000000;
global sba_shellfish=5000000;


global sba_forhire=7500000;
global sba_finfish=20500000;
global sba_shellfish=5500000;
*/
/* This is the "new" size standard for Small Businesses that NMFS*/
global sba_comm=11000000;
global sba_forhire=7500000;
/*      84 FR 34261 changed the standard for for-hire as of July 2019
https://www.federalregister.gov/documents/2019/07/18/2019-14980/small-business-size-standards-adjustment-of-monetary-based-size-standards-for-inflation
*/
global sba_forhire=8000000;

/***************************************************
1.  Construct Affiliates
***************************************************/
/* Port of chad's sas code to get ownership data.*/
/* Objective: Construct a key-file which contains VP_NUM, Affiliate_id, and ap_year.
The Affiliation variable is "constant" for all VP_NUMS which have the exact same person_id's associated with it.
Note: The affiliate_id number that is associated with an entity may change when this code is re-run and data are extracted again.  Caveat emptor.
Note2: There are some VP_NUM's that have revenue but no ownership information. These VP_NUMS are assigned an affiliate_id number in step 3.
*/

/* Min-Yang's comment: This code is slightly modified from Chad's SQL code.  It joins data from three tables (vps_owner, vps_fisher_ner, and business_owner)*/

clear;
odbc load,  exec("select distinct(b.person_id), c.business_id, a.vp_num, a.ap_year
	from permit.vps_owner c, permit.bus_own b, permit.vps_fishery_ner a
		where c.ap_num in (select max(ap_num) as ap_num from permit.vps_fishery_ner where ap_year=$yr_select group by vp_num)
	 and c.business_id=b.business_id and a.ap_num=c.ap_num;") $mysole_conn;


display "check1";
/* get rid of business_id -- they aren't necessary to what we are doing.
ML: I think business_id could have been omitted from the SQL select code*/
drop business_id;


/* important to use bysort vp_num ap_year (person_id) to consistently order the person-id's within the groups defined by vp_num and ap_year*/
/* this just generates a numeric 'suffix' for the person_id variable.  For a given VP_NUM and YEAR, the lowest person_id has the lowest jid.
This is not important for now, but will be used in the next step when arraying person ids.*/
bysort vp_num ap_year (person_id ): gen jid=_n;

/* reshape the data to wide --- array out the person ids.  Sort the data by person_id1.  For entries with the same person_id1, sort by person_id2. Etc.  */

reshape wide person_id , i(vp_num ap_year) j(jid);
sort person_id*;

/* Generate affiliate_id variable: Observations which have the same value for affiliate_id have the same distinch pattern of person_ids.
egen group() constructs a new variable taking on values 1,2,3,...., for each distinct combination of the person_id variables. The missing option allows for a missing value to be matched.  */

assert person_id1<.;
egen affiliate_id=group(person_id*), missing;
order affiliate_id ap_year vp_num;
sort affiliate_id ap_year vp_num;

sort affiliate vp_num ap_year;

/* it should be impossible for a vp_num to have 2 affiliate_id's in a year.  Check this and break the program if there are vp_nums with 2 affiliated_ids. */
duplicates tag vp_num affiliate_id ap_year, gen(mytt9);
assert mytt9==0;
drop mytt9;
/* rename ap_year as year and vp_num as permit to facilitate joining to dealer data*/
rename ap_year year;
rename vp_num permit;

tempfile ownership;
save `ownership', replace;

display "check2";
/***************************************************
2a.  Landings and revenues from Last 3 years
***************************************************/
global firstyr= $yr_select-2;
local schema "cfdbs.cfders";


/* Extraction loop
Loop over 3 years of CFDERS, extracting vessel level revenues by NESPP3.  Cast <null> sppvalues to 0.
Smash them into a single dataset.  */
forvalues yr=$firstyr/$yr_select {;
	clear;
	tempfile new;
	local files `"`files'"`new'" "'  ;
	odbc load,  exec("SELECT permit, year, nespp3, sum(nvl(sppvalue,0)) as value FROM `schema'`yr'
		group by permit, year, nespp3;")  $mysole_conn;
	save `new';
};
clear;

append using `files';




/* Minor bits of cleanup */
destring permit year, replace ;
drop if permit==190998 | permit==290998 | permit==390998 | permit==490998 | permit==000000;
renvars, lower;
compress;
display "check3";
/***************************************************
2b.  Deal with SCOQ
***************************************************/
/* drop out sc oq data */
drop if strmatch(nespp3,"754")==1;
drop if strmatch(nespp3,"769")==1;
tempfile myt1 scoq;
count if strmatch(nespp3," ");
save `myt1';



clear;
/* Extract the surfclam and ocean quahog data */
odbc load,  exec("SELECT num as permit, bush as quantity, cat, price, pd from sfoqpr") $mysole_conn;
gen str3 nespp3="754" if cat==6;
replace nespp3="769" if cat==1;
count if strmatch(nespp3," ");

/* Aggregate to the permit-year-nespp3 level*/

gen year=year(dofc((pd)));
gen value=price*quantity;
collapse (sum) value, by(permit year nespp3);
keep if year>=$firstyr & year<=$yr_select;
save `scoq', replace;

/*Join the SCOQ data back to the CFDERS data and reshape into 1 observation per permit-year */
use `myt1';
append using `scoq';
drop if value==.;
save `myt1', replace;
reshape wide value, i(permit year) j(nespp3) string;
save `myt1', replace;

/***************************************************
2c.  Compute the for-hire revenue based on VESLOG
Party and Charter only trips from VESLOGYYYYT
Handline only gear from VESLOGYYYYG
This code is loosely based on Scott's SAS code and barb's custom rec dataset

Select the sum of anglers at the permit-year level corresponding to party and charter trips that used HND Gear.
Multiply anglers by expenditure per angler to get vessel level revenue.
Merge into the revenue dataset.
A vessel may have revenue from both commerical sources and for-hire trips.
****************************************/

display "check4";
forvalues yr=$firstyr/$yr_select {;
	clear;
	tempfile new2;
	local files2 `"`files2'"`new2'" "'  ;
	odbc load,  exec("select sum(nvl(nanglers,0)) as anglers, permit from vtr.veslog`yr't where (tripcatg between 2 and 3) and tripid in (
select distinct tripid from vtr.veslog`yr'g where gearcode='HND')
group by permit;") $mysole_conn;
	gen value_permit_forhire=round(anglers*rec_exp`yr');
	gen year=`yr';
	save `new2';

};
clear;
append using `files2';
tempfile rec;
keep permit year value_permit_forhire;
sort permit year;
save `rec';


use `myt1';
merge 1:1 permit year using `rec';
drop _merge;
save `myt1', replace;




/*3. Join revenues data to affiliates (ownership data). */
merge m:1 permit using `ownership';

/*
_merge==1 there are no owner_ids. We need to create a distinct affiliation id for each of these.  I will use the permit number.
_merge==2 there were no landings.  Need to tsset, then fill  so that value==0.  We'll do this at Checkpoint 100
_merge==3. There is a match between affiliation and revenue dataset.  Nothing to do.
*/

display "check5";
replace affiliate_id=permit if _merge==1;
drop _merge;
save `myt1', replace;


/* 4.  Join to PLAN and CAT at the permit level */
/* Extract permit data for year "$yr_select" */

#delimit;
clear;
	odbc load,  exec("select vp_num, plan, cat from permit.vps_fishery_ner
		where ap_num in
			(select max(ap_num) as ap_num from permit.vps_fishery_ner where
		to_date('06/01/$yr_permit_portfolio','MM/DD/YYYY') between trunc(start_date,'DD') and trunc(end_date,'DD')
		 group by vp_num)
		 ;")  $mysole_conn;




gen str6 plancat=plan+"_"+cat;
pause;
/* store the distinct plan_cat for usage later */
levelsof plancat, local(myplans) clean;
drop plan cat;
/* there's a few 'duplicated' entries */
duplicates drop;
gen ppp=1;
reshape wide ppp, i(vp) j(plancat) string;
rename vp_num permit;
sort permit;
tempfile perms;
expand 3;
gen year=$yr_select;
bysort permit: replace year=year-_n+1;

save `perms';


/* join permit data back to dataset */
use `myt1', clear;

merge m:1 permit year using `perms';
/*This join is messy. All permit-years in the CFDBS-ownership data that do not a particular type of Federal permit (_merge=1).
	These can be filled in with 0's


 There are also federal permits with no revenues (_merge=2).

This is fixed at checkpoint 101.*/


drop _merge;







/* Checkpoint 100: Deal with permits that only show up once
	These are a special kind of awful, because they would have 1-2 years of revenue but no permits in the most recent year.
	If they had a permit in the most recent year, they'd have matched to the permit data*/
tsset permit year;
tsfill, full;




/* fill in zeros for missing values of revenue */
quietly foreach var of varlist value* {;
	replace `var'=0 if `var'==.;
};

/* 4.  Construct Affiliate level gross revenues, gross revenues by "category", and make a determination of "SMALL" and "LARGE" */
/*fill in missing affiliates with permit numbers.  This will be for vessels with no ownership information but that had landings or owned a permit*/

/* it should be impossible for a vp_num to have 2 affiliate_id's in a year.  Check this and break the program if there are vp_nums with 2 affiliated_ids. */
tempvar mytt;
duplicates tag permit affiliate_id year, gen(`mytt');
assert `mytt'==0;





/*Aggregate revenues to shellfish, finfish, commercial, and total levels
Shellfish are nespp3=700 to nespp3=806, plus nespp3=834*/
/* distinguishing between finfish and shellfish isn't necessary anymore, but we'll leave it anyway */

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

/* classify affiliate_id as small or large based on 3-year average of TOTAL revenues and the appropriate size standard.
*/
bysort affiliate_id: egen affiliate_bar=sum(value_permit);
replace affiliate_bar=affiliate_bar/3;

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


foreach var of varlist `myplans' {;
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
sort affiliate_id year;
compress;

/* this is a little dangerous on the permit categories, since TLF_3 may not always be the last one. And yet...changing this to * notation might work */
export excel affiliate_id year count_permits entity_type_$yr_select small_business permit affiliate_total affiliate_fish affiliate_forhire value_permit*  `myplans' using  "${my_datadir}/affiliates_condensed_${vintage_string}.xlsx", firstrow(variables) replace;
export excel using "${my_datadir}/affiliates_${vintage_string}.xlsx", firstrow(variables) replace;


saveold "${my_datadir}/affiliates_${vintage_string}.dta", replace version(12);

/* if your system is aware of stat-transfer, this will automatically create sas and Rdata datasets
*/

! "$stat_transfer" "${my_datadir}/affiliates_${vintage_string}.dta"  "${my_datadir}/affiliates_${vintage_string}.sas7bdat";
! "$stat_transfer" "${my_datadir}/affiliates_${vintage_string}.dta"  "${my_datadir}/affiliates_${vintage_string}.Rdata";




