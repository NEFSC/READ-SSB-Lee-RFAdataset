/*================================================================================
Script:      02_push_to_oracle.do
Repository:  READ-SSB-Lee-RFAdataset
--------------------------------------------------------------------------------
Purpose:
  Reads the final affiliates dataset (current year only), drops any existing
  Oracle table, creates a fresh table with the correct schema, inserts the
  Stata data, and grants SELECT privileges to named NEFSC colleagues.

Pipeline Position:
  Step 2 — Run manually after wrapper.do completes.
  Consumes the final .dta produced by data_joins.do; writes to Oracle.

Inputs:
  - ${my_datadir}/final/affiliates_${vintage_string}.dta

Outputs:
  - Oracle table mlee.RFA${next_year} on the NEFSC_USERS server
    Columns: affiliate_id, entity_type_${yr_select}, small_business, permit,
             value_permit, value_permit_forhire, year

Key Macros Required:
  - $my_datadir, $vintage_string, $yr_select
  - $mynova_conn        : connection string for DDL (DROP/CREATE/GRANT)
  - $myNEFSC_USERS_conn : connection string for INSERT
    NOTE: nova and NEFSC_USERS point to the same physical server. The two
    connection strings differ only in that $mynova_conn does NOT include the
    "lower" option, which is required for DDL that must preserve column name case.

SQL Connections:
  - DSN: $mynova_conn (DDL: DROP, CREATE, GRANT) via oracle_no_lower local
  - DSN: $myNEFSC_USERS_conn (INSERT) via oracle_no_lower local
  - Tables: mlee.RFA${next_year}

Notes:
  - The oracle_no_lower construction strips "lower" from the connection string
    using Stata's list-subtraction idiom. This is needed because Stata's odbc
    with the "lower" option lowercases all returned column names, but Oracle DDL
    identifiers are case-sensitive. This workaround will break silently if the
    connection string does not contain the exact word "lower".
  - capture on the DROP allows the script to proceed if the table does not yet
    exist (first run of a new year).
  - The GARFO JDBC block (commented out) requires $jar, $classname, $GARFO_URL,
    and $mygarfopwd
================================================================================
*/

* Keep only the most recent year; the Oracle table is a current-year snapshot.
# delimit ;
use "${my_datadir}/final/affiliates_${vintage_string}.dta", clear;

keep if year==$yr_select;
global next_year=$yr_select+1 ;
keep affiliate_id entity_type small_business permit value_permit value_permit_forhire year;
sort affiliate_id permit;



local nl "lower";
local oracle_no_lower: list global(mynova_conn) - local(nl);
/* SQL QUERY — DSN: $mynova_conn (via oracle_no_lower)
 Purpose: Drop the prior table for this year if it already exists.
 Tables:  mlee.RFA${next_year}
 Note:    capture prevents failure if the table does not yet exist.
*/

capture odbc exec("DROP TABLE mlee.RFA${next_year};"), `oracle_no_lower' ;

/*SQL QUERY — DSN: $mynova_conn
 Purpose: Create the RFA table with typed columns for the current-year subset.
          Column types are hard-coded; entity_type column name contains the
          year (e.g., entity_type_2024) and changes annually.
 Tables:  mlee.RFA${next_year}
 */
 
odbc exec("CREATE TABLE mlee.RFA${next_year} (
    affiliate_id NUMBER(8) ,
    entity_type_${yr_select} VARCHAR2(8 CHAR)  ,
    small_business NUMBER(1),
	permit NUMBER(6),
	value_permit FLOAT,
	value_permit_forhire FLOAT,
	year NUMBER(4)
);" ) , `oracle_no_lower';

/* Rebuild oracle_no_lower for INSERT, this time stripping "lower" from
 $myNEFSC_USERS_conn (the insert connection differs from the DDL connection).
*/
local nl "lower";
local oracle_no_lower: list global(myNEFSC_USERS_conn) - local(nl);
local nl "lower";
local oracle_no_lower: list global(myNEFSC_USERS_conn) - local(nl);

/* SQL QUERY — DSN: $myNEFSC_USERS_conn (via oracle_no_lower)
 Purpose: Insert the in-memory Stata dataset into mlee.RFA${next_year}.
 Tables:  mlee.RFA${next_year}
 Note:    "entity_type_" is a Stata abbreviation for entity_type_${yr_select}.
          Resolves correctly if only one variable starts with entity_type_.
		  */
		  
		  
odbc insert affiliate_id entity_type_ small_business permit value_permit value_permit_forhire year, table("mlee.RFA${next_year}") `oracle_no_lower' ;

/* GRANT select  */
odbc exec("GRANT SELECT on mlee.RFA${next_year} to CDEMAREST, GARDINI, JDIDDEN, NPRADHAN, RMURPHY, SWERNER, GARFO_NESFC" ) , `oracle_no_lower';





/* push to the oracle on GARFO .*/
/* I do not have privs to create a table, so this is commented out

jdbc connect, jar("$jar")  driverclass("$classname")  url("$GARFO_URL")  user("$myuid") password("$mygarfopwd") ;
capture jdbc exec("DROP TABLE mlee.RFA${next_year}");

jdbc exec("CREATE TABLE mlee.RFA${next_year} (
    affiliate_id NUMBER(8) ,
    entity_type_${yr_select} VARCHAR2(8 CHAR)  ,
    small_business NUMBER(1),
	permit NUMBER(6),
	value_permit FLOAT,
	value_permit_forhire FLOAT
)" );


jdbc insert affiliate_id entity_type_ small_business permit, table("mlee.RFA${next_year}") ;

jdbc exec("GRANT SELECT on mlee.RFA${next_year} to BGALUARDI" ) ;



*/