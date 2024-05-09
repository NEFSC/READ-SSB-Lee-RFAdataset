# delimit ;
use "${my_datadir}/final/affiliates_${vintage_string}.dta", clear;

keep if year==$yr_select;
global next_year=$yr_select+1 ;
keep affiliate_id entity_type small_business permit value_permit value_permit_forhire ;
sort affiliate_id permit;



local nl "lower";
local oracle_no_lower: list global(mynova_conn) - local(nl);


capture odbc exec("DROP TABLE mlee.RFA${next_year};"), `oracle_no_lower' ;


odbc exec("CREATE TABLE mlee.RFA${next_year} (
    affiliate_id NUMBER(8) ,
    entity_type_${yr_select} VARCHAR2(8 CHAR)  ,
    small_business NUMBER(1),
	permit NUMBER(6),
	value_permit FLOAT,
	value_permit_forhire FLOAT
);" ) , `oracle_no_lower';



odbc insert affiliate_id entity_type_ small_business permit value_permit value_permit_forhire, table("mlee.RFA${next_year}") `oracle_no_lower' ;

/*no TMURPHY, SSTEINBA on NEFSC_USERS right now.*/
odbc exec("GRANT SELECT on mlee.RFA${next_year} to CDEMARES, GARDINI, GDEPIPER, JDIDDEN, JWALDEN, KBISACK, NPRADHAN, SWERNER, DCORVI, JCOUTURE, NEFMC_DAVID_MCCARRON" ) , `oracle_no_lower';


/* push to the oracle on GARFO .*/
/* I do not have privs to create a table, so this is commented out

local nl "lower";

*local oracle_no_lower: list global(mygarfo_conn) - local(nl);
local oracle_no_lower: list global(myNEFSC_USERS_conn) - local(nl);



capture odbc exec("DROP TABLE mlee.RFA${next_year};"), `oracle_no_lower' ;


odbc exec("CREATE TABLE mlee.RFA${next_year} (
    affiliate_id NUMBER(8) ,
    entity_type_${yr_select} VARCHAR2(8 CHAR)  ,
    small_business NUMBER(1),
	permit NUMBER(6),
	value_permit FLOAT,
	value_permit_forhire FLOAT
);" ) , `oracle_no_lower';


odbc insert affiliate_id entity_type_ small_business permit, table("mlee.RFA${next_year}") `oracle_no_lower' ;
/*no TMURPHY  on NEFSC_USERS right now.*/
odbc exec("GRANT SELECT on mlee.RFA${next_year} to CDEMARES, GARDINI, GDEPIPER, JDIDDEN, JWALDEN, KBISACK, NPRADHAN, SWERNER, DCORVI, JCOUTURE, NEFMC_DAVID_MCCARRON, DCORVI, BGALUARDI, SSTEINBACK" ) , `oracle_no_lower';
