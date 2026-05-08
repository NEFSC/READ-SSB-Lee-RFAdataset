  /*
================================================================================
Script:      wrapper_extraction.do
Repository:  READ-SSB-Lee-RFAdataset
--------------------------------------------------------------------------------
Purpose:
  Top-level orchestration script for the extraction phase. Defines $firstyr,
  then calls the four extraction scripts in sequence to pull ownership, commercial
  revenues, for-hire revenues, and permit portfolio data from Oracle.  Also runs script
  to join data together.

Pipeline Position:
  Step 1 of the pipeline (extraction orchestrator).
  Must be preceded by folder_setup_globals.do.
  Does NOT call 02_push_to_oracle.do — this is run manually
  after extraction to allow inspection of intermediate files.

Inputs:
  - Globals set by folder_setup_globals.do: $my_codedir, $yr_select, $this_month

Outputs:
  - None directly; delegates to called scripts, each of which writes one
    intermediate .dta file to ${my_datadir}/intermediate/.

Key Macros Required:
  - $my_codedir   : path to stata_code/ (set by folder_setup_globals.do)
  - $yr_select    : analysis year (set by folder_setup_globals.do)
  - $this_month   : current month integer (set by folder_setup_globals.do)

SQL Connections:
  None (delegates to called scripts)

Notes:
  - $firstyr is defined here (not in 02_commercial_revenues.do as may appear
    from the extraction scripts alone). It equals $yr_select - 4, covering a
    5-year revenue window, and is consumed by both scripts 02 and 03.
  - The commented-out erase block would delete intermediate files before
    re-extraction; disabled intentionally to preserve files for debugging.
  - data_joins.do is intentionally excluded from this wrapper.
================================================================================
*/


/* Min-Yang.Lee@noaa.gov */

/* Objective: This wrapper code is used to pull data to build the "RFA" dataset. It does a few things:
1.  Construct Affiliates
2.  Revenues:
	a. Pull out landings from CFDBS  from the last 5 years.
	b. Get SCOQ revenues from a SCOQ
	c. Compute the for-hire revenue based on VESLOG
3. Pull the permit data.
*/

// The erase block below is commented out intentionally; intermediate files are
// preserved between extraction and processing phases for inspection.
/*
erase ${my_datadir}/intermediate/commercial_revenues.dta
erase ${my_datadir}/intermediate/ownership.dta
erase ${my_datadir}/intermediate/permits.dta
erase ${my_datadir}/intermediate/recreational.dta
*/

// $firstyr defines the start of the 5-year revenue window. Scripts 02 and 03
// both consume this global; they cannot be run independently without it.


global firstyr= $yr_select-4

/* SECTION: Extraction Scripts
 Called in order. Scripts 02 and 03 depend on $firstyr set above.
*/								

do "${my_codedir}/extraction_code/01_extract_ownership.do"
do "${my_codedir}/extraction_code/02_commercial_revenues.do"
do "${my_codedir}/extraction_code/03_for_hire_revenues.do"
do "${my_codedir}/extraction_code/04_permit_portfolio.do"


do "${my_codedir}/processing_code/data_joins.do"


/* SECTION: Pre-June-1 Warning
 Reminds the user that data is preliminary if run before the permit cutoff.
*/


if $this_month<6{
    di "Today is"  %td_CCYY_NN_DD date(c(current_date), "DMY")
    di "It is before the Jun 1 permit cutoff, so this data is preliminary"
}




