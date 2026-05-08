/*
================================================================================
Script:      01_extract_ownership.do
Repository:  READ-SSB-Lee-RFAdataset
--------------------------------------------------------------------------------
Purpose:
  Constructs a vessel-to-affiliate mapping for year $yr_select. Pulls all
  person IDs associated with each permit from three Oracle GARFO tables,
  reshapes to wide so each row represents a unique ownership structure, then
  uses egen group() to assign a common affiliate_id to permits that share an
  identical set of owners.

Pipeline Position:
  Step 1a of extraction — called first by wrapper_extraction.do.
  Produces the ownership key file consumed by data_joins.do.

Inputs:
  - Oracle DB via $myNEFSC_USERS_conn:
    * nefsc_garfo.permit_vps_owner       : links permit (ap_num) to business_id
    * nefsc_garfo.client_bus_own         : links business_id to person_id
    * nefsc_garfo.permit_vps_fishery_ner : permit applications (vp_num, ap_year)

Outputs:
  - ${my_datadir}/intermediate/ownership_${vintage_string}.dta
    Columns: affiliate_id, year (= $yr_select), permit, person_id1...person_idN

Key Macros Required:
  - $yr_select            : analysis year
  - $myNEFSC_USERS_conn   : ODBC connection string for the NEFSC_USERS Oracle server
  - $my_datadir, $vintage_string

SQL Connections:
  - DSN: $myNEFSC_USERS_conn
  - Tables: nefsc_garfo.permit_vps_owner, nefsc_garfo.client_bus_own,
            nefsc_garfo.permit_vps_fishery_ner

Notes:
  - affiliate_id values are arbitrary sequential integers from egen group() and
    will change on every re-run. This is documented in output_data_description.md
    Warning 3; downstream users must not treat affiliate_id as a stable key
    across vintages.
  - Firms where a business owns another business show only one ownership level;
    nested structures are not propagated
================================================================================
*/


/***************************************************
1.  Construct Affiliates
***************************************************/
/* Port of chad's sas code to get ownership data.*/
/* Objective: Construct a key-file which contains VP_NUM, Affiliate_id, and ap_year.
The Affiliation variable is "constant" for all VP_NUMS which have the exact same person_id's associated with it.
Note: The affiliate_id number that is associated with an entity may change when this code is re-run and data are extracted again.  Caveat emptor.
Note2: There are some VP_NUM's that have revenue but no ownership information. These VP_NUMS are assigned an affiliate_id number in step 3.
*/

/* Min-Yang's comment: This code is slightly modified from Chad's SQL code.  It joins data from three tables (vps_owner, vps_fisher_ner, and business_owner)*/
#delimit ;
clear;
/* SQL QUERY — DSN: $myNEFSC_USERS_conn
 Purpose: Retrieve all person_ids associated with each permit for $yr_select.
          The correlated subquery selects max(ap_num) per vessel per year to
          pick the most recent permit application, giving one canonical
          ownership record per vessel-year.
 Tables:  nefsc_garfo.permit_vps_owner, nefsc_garfo.client_bus_own,
          nefsc_garfo.permit_vps_fishery_ner
 Note:    $yr_select is interpolated directly into the WHERE clause.
*/
odbc load,  exec("select distinct(b.person_id), c.business_id, a.vp_num, a.ap_year
	from nefsc_garfo.permit_vps_owner c, nefsc_garfo.client_bus_own b, nefsc_garfo.permit_vps_fishery_ner a
		where c.ap_num in (select max(ap_num) as ap_num from nefsc_garfo.permit_vps_fishery_ner where ap_year=$yr_select group by vp_num)
	 and c.business_id=b.business_id and a.ap_num=c.ap_num;") $myNEFSC_USERS_conn;
display "check1";
/* get rid of business_id -- they aren't necessary to what we are doing.
ML: I think business_id could have been omitted from the SQL select code*/
drop business_id;


/* ----------------------------------------------------------------------------
 SECTION: Ownership Reshape
 Assigns a consistent numeric rank (jid) to each person_id within a
 vessel-year group ordered by person_id value. This ensures that the same
 individual always gets the same column position across runs, which is
 required for affiliate_id to be assigned consistently.
 Reshapes from long (one row per person) to wide (one row per permit-year
 with columns person_id1, person_id2, ...).
 ----------------------------------------------------------------------------
*/

/* important to use bysort vp_num ap_year (person_id) to consistently order the person-id's within the groups defined by vp_num and ap_year*/
/* this just generates a numeric 'suffix' for the person_id variable.  For a given VP_NUM and YEAR, the lowest person_id has the lowest jid.
This is not important for now, but will be used in the next step when arraying person ids.*/
bysort vp_num ap_year (person_id ): gen jid=_n;

/* reshape the data to wide --- array out the person ids.  Sort the data by person_id1.  For entries with the same person_id1, sort by person_id2. Etc.  */

reshape wide person_id , i(vp_num ap_year) j(jid);
sort person_id*;


/* ----------------------------------------------------------------------------
 SECTION: Affiliate ID Assignment
 Assigns a common affiliate_id to permits sharing identical ownership structure
 (same ordered set of person_ids). Permits with no ownership records in the
 Oracle tables receive a sentinel person_id of 99000000 + vp_num so they still
 receive a unique affiliate_id rather than being grouped with each other.
 ----------------------------------------------------------------------------
*/
/* Generate affiliate_id variable: Observations which have the same value for affiliate_id have the same distinch pattern of person_ids.
egen group() constructs a new variable taking on values 1,2,3,...., for each distinct combination of the person_id variables. The missing option allows for a missing value to be matched.  */

/* there are a few firms with nested ownership. This doesn't propagate down.  I can't do much with this, except fill something in.*/
/* for now, I'm going to take "99+permit number" for those*/
replace person_id1=99000000+vp_num if person_id1==.; // HARD-CODED: 99000000 sentinel offset; ensures ownership-gap permits get unique affiliate_ids
assert person_id1<.;
egen affiliate_id=group(person_id*), missing;
order affiliate_id ap_year vp_num;

sort affiliate_id vp_num ap_year;

/* ----------------------------------------------------------------------------
 SECTION: Duplicate Check and Variable Renaming
 Asserts no permit has two different affiliate_ids in the same year (which
 would indicate a data integrity problem). Renames variables to match the
 naming conventions expected by data_joins.do.
 ----------------------------------------------------------------------------
*/

/* it should be impossible for a vp_num to have 2 affiliate_id's in a year.  Check this and break the program if there are vp_nums with 2 affiliated_ids. */
duplicates tag vp_num affiliate_id ap_year, gen(mytt9);
assert mytt9==0;
drop mytt9;
/* rename ap_year as year and vp_num as permit to facilitate joining to dealer data*/
rename ap_year year;
rename vp_num permit;
sort affiliate_id year permit;
save ${my_datadir}/intermediate/ownership_${vintage_string}.dta, replace ;



