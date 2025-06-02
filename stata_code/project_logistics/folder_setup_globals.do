/* Set up global macros to point to folders */

version 15.1
scalar drop _all

#delimit ;

if strmatch("$user","minyang"){;
global my_projdir "/home/mlee/Documents/projects/RFAdataset";
};

if strmatch("$user","minyangWin"){;
global my_projdir "C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset";

};

/* setup data folder */
global my_datadir "${my_projdir}\data_folder";


global my_codedir "${my_projdir}\stata_code";


local date: display %td_CCYY_NN_DD date(c(current_date), "DMY");
global today_date_string = subinstr(trim("`date'"), " " , "_", .);
global vintage_string $today_date_string;


cap mkdir ${my_datadir}/intermediate;
cap mkdir ${my_datadir}/final;



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
global permit_date_pull "'06/01/${yr_permit_portfolio}'" ;
/*Rec expenditures per angler and CPI for adjusting from the 2011 expenditure survey

 CPI-U  CUUR0000SA0
 https://data.bls.gov/timeseries/CUUR0000SA0
 No idea why I'm using -U
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
scalar C2021=275.703;
scalar C2022=296.963;
scalar C2023=306.996;
scalar C2024=315.233;

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
scalar rec_exp2020=137.82;
scalar rec_exp2021=140.53;
scalar rec_exp2022=143.24;

scalar rec_exp2023=round(rec_exp2022*C2023/C2022, .01);
scalar rec_exp2024=round(rec_exp2022*C2024/C2022, .01);


/* This is the 2015 size standard for Small Businesses that NMFS uses.   80FR249. Page 81194*/
global sba_comm=11000000;
global sba_forhire=7500000;
/*      84 FR 34261 changed the for-hire standard as of July 2019
https://www.federalregister.gov/documents/2019/07/18/2019-14980/small-business-size-standards-adjustment-of-monetary-based-size-standards-for-inflation
*/
global sba_forhire=8000000;



if $this_month<6{;
    di "Today is"  %td_CCYY_NN_DD date(c(current_date), "DMY");
    di "It is before the Jun 1 permit cutoff, so this data is preliminary";
	global vintage_string PROTOTYPE_$today_date_string ;

};







