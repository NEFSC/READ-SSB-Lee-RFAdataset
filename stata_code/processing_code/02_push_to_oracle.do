# delimit ;
use "${my_datadir}/final/affiliates_${vintage_string}.dta", clear;

keep if year==$yr_select;
keep affiliate_id entity_type small_business permit;
sort affiliate_id permit;


local nl "lower";
local oracle_no_lower: list global(mysole_conn) - local(nl);


odbc exec("DROP TABLE mlee.RFA2022;"), `oracle_no_lower' ;


odbc exec("CREATE TABLE mlee.RFA2022 (
    affiliate_id NUMBER(8) ,
    entity_type_2022 VARCHAR2(8 CHAR)  ,
    small_business NUMBER(1),
	permit NUMBER(6)
);" ) , `oracle_no_lower';



odbc insert affiliate_id entity_type_ small_business permit, table("mlee.RFA2022") `oracle_no_lower' ;

odbc exec("GRANT SELECT on mlee.RFA2022 to GARDINI,GDEPIPER, SSTEINBA,CDEMARES,JWALDEN,KBISACK,SWERNER,TMURPHY" ) , `oracle_no_lower';
