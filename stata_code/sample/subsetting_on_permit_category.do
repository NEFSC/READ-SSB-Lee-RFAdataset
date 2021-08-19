/* Code to subset firms that have at least one permit of a certain category  */


version 16.1
clear
set scheme s2color
global RFA_dataset  "affiliates_2021_06_07.dta"

use $RFA_dataset, clear








/* Keep affiliate_id's that have at least one of the categorical variables in the keeplist ==1 in the most recent year*/


/* List of permit_categories I want to keep */
local keeplist HRG_A HRG_B HRG_C HRG_D HRG_E 

/*Add up the number of herring permits help by a vp_num */
egen keep_flag=rowtotal(`keeplist')

/* zero out everything that is not the last year */
qui summ year
local maxy=`r(max)'
replace keep_flag=0 if year~=`maxy'

/* drop if the the affiliate did not have at least one of the permits */
bysort affiliate_id : egen kf2=total(keep_flag)
keep if kf2>=1
drop kf2 keep_flag

qui compress
