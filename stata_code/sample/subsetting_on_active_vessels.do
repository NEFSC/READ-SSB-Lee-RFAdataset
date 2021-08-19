

/* Code to subset firms that had positive herring revenue in the most recent year or those that had any herring revenue in the past 3 years.  */


use $RFA_dataset, clear

drop person*



/* Pick off the last year */
qui summ year
local maxy=`r(max)'


/* STEP 2: Keep affiliate_id's that have at least $1 of herring revenue in the most recent year */
gen h_temp=0
replace h_temp=value168 if year==`maxy'
bysort affiliate_id : egen kf2=total(h_temp)
keep if kf2>=1
drop kf2 h_temp



/* Alternative STEP 2: Keep affiliate_id's that have at least $1 of herring revenue in the last three years */
gen h_temp=0
replace h_temp=value168 /*if year==`maxy'*/
bysort affiliate_id : egen kf2=total(h_temp)
keep if kf2>=1
drop kf2 h_temp




