/* setup global macros for connecting to oracle sole or nova under windows and linux */
/*Because there may be semicolons inside the connection string, you should use carriage returns as delimiters in this file*/
/* Usage: Either 
1. copy/paste parts of this into your profile.do file OR
2. Run this file right before you need to extract data.
*/

/********************************************************************************************************/
/* PART 0: Preamble */
version 15.1
#delimit cr
global myuid "your_uid"
global mypwd "your_pwd_here"
global mygarfo_pwd "your_garfo_pwd"
/********************************************************************************************************/
/********************************************************************************************************/


/********************************************************************************************************/
/********************************************************************************************************/
/* PART 1: WINDOWS */
/* if DMS has properly configured your ODBC connections for sole, nova,and musky, this will work on Windows. */
/* Min-Yang's preferred approach to connecting to NEFSC's Oracle from Stata in Mint14 is:


odbc load,  exec("select something from table 
	where blah blah blah;") $mysole_conn ;

	
where $mysole_conn contains a connection string for sole */

global mysole_conn "dsn(sole) user($myuid) password($mypwd)"
global mynova_conn "dsn(nova) user($myuid) password($mypwd)"
global mygarfo_conn "dsn(musky) user($myuid) password($mygarfo_pwd)"
/********************************************************************************************************/
/********************************************************************************************************/





/* PART 2: LINUX */
/***************************************************************************************************/
/* if you have a properly set up odbcinst.ini , then this will work. */
global mysole_conn "Driver={OracleODBC-11g};Dbq=path.to.sole.server.gov:PORT/sole;Uid=mlee;Pwd=$mypwd;"
global mynova_conn "Driver={OracleODBC-11g};Dbq=path.to.nova.server.gov:PORT/nova;Uid=mlee;Pwd=$mypwd;"
global mygarfo_conn "Driver={OracleODBC-11g};Dbq=NNN.NNN.NN.NNN/perhaps.more.letters.here.nfms.gov;Uid=mlee;Pwd=$mygarfo_pwd;"


/* If not, you'll need to paste in the full path to your libsqora.so.11.1 driver in the "Driver" part. 
global mysole_conn "Driver=/usr/lib/oracle/11.2/client64/lib/libsqora.so.11.1;Dbq=path.to.sole.server.gov:PORT/sole;Uid=mlee;Pwd=$mypwd;"
global mynova_conn "Driver=/usr/lib/oracle/11.2/client64/lib/libsqora.so.11.1;Dbq=path.to.nova.server.gov:PORT/nova;Uid=mlee;Pwd=$mypwd;"
*/


/********************************************************************************************************/
/********************************************************************************************************/
/********************************************************************************************************/


/*code to test
clear
odbc load, exec("select * from cfspp") $mysole_conn

clear


*/
