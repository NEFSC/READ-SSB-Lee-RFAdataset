# Overview
In general, I'm trying to keep code, raw data, processed data, results, and images separate.  I have soft coded these directories; and only two files needs to be changed (the ones in project_logistics) to change the project directories and subdirectories.

Smaller bits of analysis that are related (or depend on previous) are collected together in a wrapper.

# Cloning from Github and other setup
Min-Yang is using Rstudio to write .Rmd or .md documentation. He is also using Rstudio's git version control to commit/push/pull from github. It works reasonably well.  You will also need git installed.

The easist thing to do is to clone this repository to a place on your computer. [Here's a starting guide](https://cfss.uchicago.edu/setup/git-with-rstudio/).  Don't put spaces in the name.  Cloning the repository will set up many, but not all of the folders.

Min-Yang put the project into:
```
C:\Users\Min-Yang.Lee\Documents\RFAdataset
```
Pay attention to where you put this, you will need it later.

## Set up Oracle and ODBC
1.  Open up /stata_code/sample/odbc_connection_macro_sample.do. 
1.  Delete the Operating system section that is irrelevant to you.  Enter your own information (oracle username and password).  
1.  Rename and save it in a place you can find. Min-Yang put it into 
```
C:\Users\Min-Yang.Lee\Documents\common\odbc_setup_macros.do
```
Pay attention to where you put this, you will need it later.


## Set up your profile.do
1. Open up sample_profile.do.
1. Enter and modify with your own information (username,directories).  You will want the RFAdataset macro to point to the "project_logistics\folder_setup_globals.do" that is in your project directory (for me this is C:\Users\Min-Yang.Lee\Documents\RFAdataset
1. Save it as "C:\ado\profile.do".  [Here is the stata manual](https://www.stata.com/manuals15/gsub.pdf). 


## Set up the rest of the project. 
1. Open up "project_logistics/run_this_once-folder_setup.do"
1.  Add an "if" statement analogous to lines 15-18.  Put this below minyang's if statement.  Change the directory to match the one you used when you initially cloned this repository.
1. Open up "project_logistics/folder_setup_globals.do"
1.  Add an "if" statement analogous to lines 7-11. Put this below minyang's if statement.  Change the directory to match the one you used when you initially cloned this repository.  Change the quietly do line to run the bit of code that sets up your odbc connections.
4. start stata. Type
```
do $RFAdataset 
do "/${my_codedir}/project_logistics/run_this_once_folder_setup.do"
```

# Running code:

## Requirements
You will need permission to view data in these tables:
1. PERMIT.vps_owner,  PERMIT.bus_own, PERMIT.vps_fishery_ner
1. VTR.veslogYYYYg, VTR.veslogYYYYt  
1. CFDBS.cfdersYYYY 
1. SFCLAM.sfoqpr

Start Stata. Type:
```
do $RFAdataset 
do "${stata_code}/construct_ownership_dataset.do"
```

# Description of the folders

## data_folder
This is where the dataset should be saved.

## Documentation
Documentation

## stata_code
Where I put the stata code to construct the RFA data.

### project_logistics
A pair of small do files to set up folders and then make stata aware of folders.

### sample
Sample code for a profile.do, odbc setup, and how to use the output data.


