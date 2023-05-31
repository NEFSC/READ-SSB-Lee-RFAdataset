

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
save ${my_datadir}/intermediate/recreational.dta, replace;



