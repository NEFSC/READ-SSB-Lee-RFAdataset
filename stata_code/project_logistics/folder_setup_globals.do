/* Set up global macros to point to folders */

version 15.1

#delimit ;

if strmatch("$user","minyang"){;
global my_projdir "/home/mlee/Documents/projects/RFAdataset";
};

if strmatch("$user","minyangWin"){;
global my_projdir "C:/Users/min-yang.lee/Documents/READ-SSB-Lee-RFAdataset";

};

/* setup data folder */
global my_datadir "${my_projdir}\data_folder";


global my_codedir "${my_projdir}\stata_code";


local date: display %td_CCYY_NN_DD date(c(current_date), "DMY");
global today_date_string = subinstr(trim("`date'"), " " , "_", .);
global vintage_string $today_date_string;
