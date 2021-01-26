# Overview
This repository can be found at https://github.com/minyanglee/RFAdataset/

This repository holds code to assemble ownership data for RFAA analysis.  This readme contains info about how to get and run the code. 

Please see [here](https://github.com/minyanglee/RFAdataset/blob/master/documentation/output_data_description.md) for documentation on the dataset

# Getting started
Please see [here](https://github.com/NEFSC/READ-SSB-Lee-project-templates) 


## Cloning from Github and other setup
Min-Yang is using Rstudio to write .Rmd or .md documentation. He is also using Rstudio's git version control to commit/push/pull from github. It works reasonably well.  You will also need to install git.

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

# Distribution

Min-Yang has a email distribution list:
1. NEFSC SSB
1. MAFMC staff
1. NEFMC staff





# NOAA Requirements
“This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an ‘as is’ basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.”


1. who worked on this project:  Min-Yang
1. when this project was created: Jan, 2021 
1. what the project does: Assembles data for RFA analysis. 
1. why the project is useful:  Assembles data for RFA analysis 
1. how users can get started with the project: Download and follow the readme
1. where users can get help with your project:  email me or open an issue
1. who maintains and contributes to the project. Min-Yang

# License file
See here for the [license file](https://github.com/minyanglee/RFAdataset/blob/master/license.md)
