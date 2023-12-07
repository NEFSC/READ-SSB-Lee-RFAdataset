/* Extract permit data for year "$yr_select" */

#delimit;
clear;
	odbc load,  exec("select vp_num, plan, cat from NEFSC_GARFO.PERMIT_VPS_FISHERY_NER
		where ap_num in
			(select max(ap_num) as ap_num from NEFSC_GARFO.PERMIT_VPS_FISHERY_NER where
		to_date(${permit_date_pull},'MM/DD/YYYY') between trunc(start_date,'DD') and trunc(end_date,'DD')
		 group by vp_num)
		 ;")  $myNEFSC_USERS_conn;




gen str6 plancat=plan+"_"+cat;
drop plan cat;
/* there's a few 'duplicated' entries */
duplicates drop;
gen ppp=1;
reshape wide ppp, i(vp) j(plancat) string;
rename vp_num permit;
sort permit;
tempfile perms;
expand 5;
gen year=$yr_select;
bysort permit: replace year=year-_n+1;

save ${my_datadir}/intermediate/permits.dta, replace;





