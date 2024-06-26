/***************************************************
2a.  Commercial Landings and revenues from Last 5 years
***************************************************/
#delimit ; 

global firstyr= $yr_select-4;

	clear;

/* Pull data from CAMS, group by permit, year and species */
odbc load,  exec("select permit, year, sum(nvl(value,0)) as value, itis_tsn from cams_land cl where 
		cl.year between $firstyr and $yr_select and itis_tsn is not NULL and itis_tsn<>0
        group by permit, year, itis_tsn;") $myNEFSC_USERS_conn;
		
		
/* Minor bits of cleanup */
destring permit year, replace ;
drop if permit==190998 | permit==290998 | permit==390998 | permit==490998 | permit==000000;
renvars, lower;
compress;
display "check3";

rename value value_ ;

preserve;
collapse (sum) value_, by(permit year);
tempfile total;
gen itis_tsn="ZZZZZZ";
save `total';
restore;
append using `total';


reshape wide value_, i(permit year) j(itis_tsn) string;
rename value_ZZZZZZ value_permit_commercial;
label var value_permit_commercial "value from commercial fishing";
save ${my_datadir}/intermediate/commercial_revenues_${vintage_string}.dta, replace;


