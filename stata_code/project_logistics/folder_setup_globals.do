/* Set up global macros to point to folders */

version 15.1

#delimit ;

if strmatch("$user","minyang"){;
global my_projdir "/home/mlee/Documents/projects/RFAdataset";
quietly do "/home/mlee/Documents/Workspace/technical folder/do file scraps/odbc_connection_macros.do";
global oracle_cxn "conn("$mysole_conn") lower";
};

if strmatch("$user","minyangWin"){;
global my_projdir "C:\Users\Min-Yang.Lee\Documents\RFAdataset";
quietly do "C:\Users\Min-Yang.Lee\Documents\common\odbc_setup_macros.do";

};

/* setup data folder */
global my_datadir "${my_projdir}\data_folder";


global my_codedir "${my_projdir}\stata_code";


local date: display %td_CCYY_NN_DD date(c(current_date), "DMY");
global today_date_string = subinstr(trim("`date'"), " " , "_", .);
global vintage_string $today_date_string;
