/* 
Min-Yang's preferred approach to connecting to NEFSC's Oracle from Stata is:

odbc load,  exec("select something from table 
	where logical 
		group by thing;")
	conn("$mysole_conn") lower;

where $mysole_conn contains a connection string for sole

This sample file shows how to build one.
Because there are semicolons inside the connection string, you should not use semicolons as delimiters*/

version 15.1
#delimit cr
global myuid "mlee"
global mypwd "your_pwd_here"
global mynero_pwd "your_other_pwd"



/* if you have a properly set up odbcinst.ini , then this will work. */
global mysole_conn "Driver={OracleODBC-11g};Dbq=path.to.sole.server.gov:PORT/sole;Uid=mlee;Pwd=$mypwd;"
global mynova_conn "Driver={OracleODBC-11g};Dbq=path.to.nova.server.gov:PORT/nova;Uid=mlee;Pwd=$mypwd;"
global mynero_conn "Driver={OracleODBC-11g};Dbq=NNN.NNN.NN.NNN/perhaps.more.letters.here.nfms.gov;Uid=mlee;Pwd=$mynero_pwd;"


/* If not, you'll need to paste in the full path tor your libsqora.so.11.1 driver. 

global mysole_conn "Driver=/usr/lib/oracle/11.2/client64/lib/libsqora.so.11.1;Dbq=path.to.sole.server.gov:PORT/sole;Uid=mlee;Pwd=$mypwd;"
global mynova_conn "Driver=/usr/lib/oracle/11.2/client64/lib/libsqora.so.11.1;Dbq=path.to.nova.server.gov:PORT/nova;Uid=mlee;Pwd=$mypwd;"
*/
