# Overview
In general, I'm trying to keep code, raw data, processed data, results, and images separate.  I have soft coded these directories; and only two files needs to be changed (the ones in project_logistics) to change the project directories and subdirectories.

Smaller bits of analysis that are related (or depend on previous) are collected together in a wrapper.

# Cloning from Github and other setup
Min-Yang is using Rstudio to write Rmd and it's git version controling to commit/push/pull from github. It works reasonably well.  You will also need git installed.

The easist thing to do is to clone this repository to a place on your computer. [Here's a starting guide](https://cfss.uchicago.edu/setup/git-with-rstudio/).  Don't put spaces in the name.  This will set up many, but not all of the folders.

His windows computer has put the incomemobility project into:
```
C:\Users\Min-Yang.Lee\Documents\RFAdataset
```
and his Linux computer has the incomemobility project in:
```
/home/mlee/Documents/projects/RFAdataset
```
But you can put them elsewhere.

## Set up the rest of the folders (Run this once)
Download the sample_profile.do.  Rename it to profile.do and put in your own information (some username, some directories).  
start stata.
type
```
do $RFAdataset 
do "/${my_codedir}/project_logistics/run_this_once_folder_setup.do"

```



# Running code:

```
do $RFAdataset 
do "${stata_code}/construct_ownership_dataset.do"

```

# Description of the folders

## project_logistics
A pair of small do files to set up folders and then make stata aware of folders.
