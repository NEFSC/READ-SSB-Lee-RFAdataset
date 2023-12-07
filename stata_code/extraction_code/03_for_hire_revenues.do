

/***************************************************
03.  Compute the for-hire revenue based on VESLOG
Party and Charter only trips from VESLOGYYYYT
Handline only gear from VESLOGYYYYG
This code is loosely based on Scott's SAS code and barb's custom rec dataset

Select the sum of anglers at the permit-year level corresponding to party and charter trips that used HND Gear.
Multiply anglers by expenditure per angler to get vessel level revenue.
Merge into the revenue dataset.
A vessel may have revenue from both commerical sources and for-hire trips.
****************************************/
#delimit ; 

clear;

odbc load,  exec("select VESSEL_PERMIT_NUM as permit, extract(YEAR FROM DATE_SAIL) as year,  sum(nvl(nanglers,0)) as anglers from NEFSC_GARFO.TRIP_REPORTS_DOCUMENT where 
	(tripcatg between 2 and 3) and 
	docid in (select distinct docid from NEFSC_GARFO.TRIP_REPORTS_IMAGES where GEARCODE='HND') and
	extract(YEAR FROM DATE_SAIL) BETWEEN $firstyr and $yr_select
	group by VESSEL_PERMIT_NUM, extract(YEAR FROM DATE_SAIL);") $myNEFSC_USERS_conn;

gen value_permit_forhire=round(anglers*rec_exp`yr');
sort permit year;
save ${my_datadir}/intermediate/recreational.dta, replace;



