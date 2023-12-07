/***************************************************
2a.  Commercial Landings and revenues from Last 5 years
***************************************************/
#delimit ; 

global firstyr= $yr_select-4;

	clear;

/* Pull data from CAMS, group by permit, year and species */
odbc load,  exec("select permit, year, sum(nvl(value,0)) as value, itis_tsn from cams_garfo.cams_land cl where 
		cl.year between $firstyr and $yr_select
        group by permit, year, itis_tsn;") $myNEFSC_USERS_conn;
		
		
/* Minor bits of cleanup */
destring permit year, replace ;
drop if permit==190998 | permit==290998 | permit==390998 | permit==490998 | permit==000000;
renvars, lower;
compress;
display "check3";



reshape wide value, i(permit year) j(itis_tsn) string;
save ${my_datadir}/intermediate/commercial_revenues.dta, replace;


