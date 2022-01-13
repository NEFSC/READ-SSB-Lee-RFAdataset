version 15.1

#delimit ;


/*Set "my_projdir" to the location where you have cloned the dataset.*/

if strmatch("$user","minyang"){;
global my_projdir "/home/mlee/Documents/projects/RFAdataset";
};
if strmatch("$user","minyangWin"){;
global my_projdir "C:/Users/Min-Yang.Lee/Documents/RFAdataset";
};

global my_codedir "${my_projdir}/stata_code";
cap mkdir $my_codedir;

/* setup data folder */
global my_datadir "${my_projdir}/data_folder";
cap mkdir $my_datadir;

