
/* Min-Yang.Lee@noaa.gov */

/* Objective: This wrapper code is used to pull data to build the "RFA" dataset. It does 6 things:
1.  Construct Affiliates
2.  Revenues:
	a. Pull out landings from CFDBS  from the last 5 years.
	b. Get SCOQ revenues from a SCOQ
	c. Compute the for-hire revenue based on VESLOG
3. Pull the permit data.
*/



do "${my_codedir}/extraction_code/01_extract_ownership.do"
do "${my_codedir}/extraction_code/02_commercial_revenues.do"
do "${my_codedir}/extraction_code/03_for_hire_revenues.do"
do "${my_codedir}/extraction_code/04_permit_portfolio.do"














