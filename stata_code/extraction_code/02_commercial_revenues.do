/***************************************************
2a.  Commercial Landings and revenues from Last 5 years
***************************************************/
#delimit ; 

global firstyr= $yr_select-4;
local schema "cfdbs.cfders";


/* Extraction loop
Loop over 5 years of CFDERS, extracting vessel level revenues by NESPP3.  Cast <null> sppvalues to 0.
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
save ${my_datadir}/intermediate/commercial_revenues.dta, replace;


