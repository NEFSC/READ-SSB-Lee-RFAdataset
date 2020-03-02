
/* Here are a few pieces of code that use the RFA dataset to do something*/



/* PRELIMINARIES */
/* Set up folders and oracle connection*/

clear
version 15.1
scalar drop _all
pause off

#delimit ;

global user minyang;


if strmatch("$user","minyang"){;
global my_projdir "/home/mlee/Documents/Workspace/ownership/RFAdataset";
quietly do "/home/mlee/Documents/Workspace/technical folder/do file scraps/odbc_connection_macros.do";
};

if strmatch("$user","scott"){;
/* Scott would put his preferred project directory here. 
He would put the code needed to construct his odbc connection string here to */
};

global my_codedir "${my_projdir}/stata_code";
global my_datadir "${my_projdir}/data_folder";
globa yr_select 2018;



use "${my_datadir}/affiliates_${yr_select}A.dta";

/* Setting:  There is a proposed regulation that would affect the A,B, and C herring vessels. 
You need to
1.  Estimate the number of large and small entities 
2.  Characterize them */


/* Step 1: Estimate the number of large and small entities 
Approach: The holdings of each permit number are in the PLAN_CAT columns.  FLAG permits that have HRG_A, HRG_B, or HRG_C==1.
Retain only the entities that have at least of those in the most recent year.
	Because the PLAN_CAT columns are constructed based on the most recent year relatively straightforward
*/

gen HRG_LA=HRG_A+HRG_B+HRG_C;
replace HRG_LA=1 if HRG_LA>=1;

bysort affiliate_id: egen flag_in=total(HRG_LA);
replace flag_in=1 if flag_in>=1;

keep if flag_in==1;
sort affiliate_id year;

/* How many large */
egen tag_affiliate_year=tag(affiliate_id year);

/* how many small and large businesses*/
tab small_business if tag_affiliate_year==1 & year==$yr_select ;

/* average revenues by small and large */
bysort small_business: summ affiliate_total if tag_affiliate_year==1 & year==$yr_select;

/* median revenues by small and large */
bysort small_business: centile affiliate_total if tag_affiliate_year==1 & year==$yr_select;



/* Average HERRING revenues by small and large 
value168 is herring revenue*/

bysort affiliate_id year: egen total_herring=total(value168);

bysort small_business: summ total_herring if tag_affiliate_year==1 & year==$yr_select;

/* median herring revenues by small and large */
bysort small_business: centile total_herring if tag_affiliate_year==1 & year==$yr_select;

/* how many firms that are permitted to fish herring are fishing in the most recent year */

bysort small_business: count if total_herring>=1 & tag_affiliate_year==1 &year==$yr_select;


