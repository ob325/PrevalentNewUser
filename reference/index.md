# Package index

## Getting data

Functions for extracting cohorts, exposure sets, and covariates from a
database in the OMOP Common Data Model.

- [`getDbPnuData()`](https://ob325.github.io/PrevalentNewUser/reference/getDbPnuData.md)
  : Load prevalent new-user study data from a database
- [`getDbExposureSets()`](https://ob325.github.io/PrevalentNewUser/reference/getDbExposureSets.md)
  : Compute exposure sets on a database server
- [`savePnuData()`](https://ob325.github.io/PrevalentNewUser/reference/savePnuData.md)
  : Save a PnuData object to disk
- [`loadPnuData()`](https://ob325.github.io/PrevalentNewUser/reference/loadPnuData.md)
  : Load a PnuData object from disk
- [`isPnuData()`](https://ob325.github.io/PrevalentNewUser/reference/isPnuData.md)
  : Test whether an object is a PnuData instance
- [`show(`*`<PnuData>`*`)`](https://ob325.github.io/PrevalentNewUser/reference/PnuData-class.md)
  : An S4 class for prevalent new-user study data
- [`summary(`*`<PnuData>`*`)`](https://ob325.github.io/PrevalentNewUser/reference/summary-PnuData-method.md)
  : Summarise a PnuData object

## Simulation

Functions for generating synthetic PNU study populations with a known
treatment effect, for testing and method development.

- [`createSimulationArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createSimulationArgs.md)
  : Create simulation arguments
- [`simulatePnuData()`](https://ob325.github.io/PrevalentNewUser/reference/simulatePnuData.md)
  : Simulate a PnuData object with a known treatment effect

## Analysis pipeline

Functions that implement the sequential steps of a PNU analysis.

- [`createStudyPopulationArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createStudyPopulationArgs.md)
  : Create study population arguments
- [`createStudyPopulation()`](https://ob325.github.io/PrevalentNewUser/reference/createStudyPopulation.md)
  : Create a study population from a PnuData object
- [`createTcpsArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createTcpsArgs.md)
  : Create TCPS fitting arguments
- [`fitTcps()`](https://ob325.github.io/PrevalentNewUser/reference/fitTcps.md)
  : Fit a time-conditional propensity score model
- [`createMatchingArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createMatchingArgs.md)
  : Create matching arguments
- [`matchOnTcps()`](https://ob325.github.io/PrevalentNewUser/reference/matchOnTcps.md)
  : Match on the time-conditional propensity score
- [`createBalanceArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createBalanceArgs.md)
  : Create covariate balance arguments
- [`computeCovariateBalance()`](https://ob325.github.io/PrevalentNewUser/reference/computeCovariateBalance.md)
  : Compute covariate balance before and after matching
- [`createOutcomeModelArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createOutcomeModelArgs.md)
  : Create outcome model arguments
- [`fitOutcomeModel()`](https://ob325.github.io/PrevalentNewUser/reference/fitOutcomeModel.md)
  : Fit an outcome model on the matched population
- [`createBootstrapArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createBootstrapArgs.md)
  : Create bootstrap arguments
- [`bootstrapCi()`](https://ob325.github.io/PrevalentNewUser/reference/bootstrapCi.md)
  : Bootstrap confidence intervals for the treatment effect

## Calibration

Empirical calibration of p-values and confidence intervals using
negative control outcomes.

- [`calibrateEstimates()`](https://ob325.github.io/PrevalentNewUser/reference/calibrateEstimates.md)
  : Apply empirical calibration to study estimates

## Running multiple analyses

Functions for running multiple analysis variants in a single call.

- [`createPnuCohortArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createPnuCohortArgs.md)
  : Create PNU cohort arguments
- [`createPnuAnalysisArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createPnuAnalysisArgs.md)
  : Create a PNU analysis specification
- [`runPnuAnalyses()`](https://ob325.github.io/PrevalentNewUser/reference/runPnuAnalyses.md)
  : Run a list of prevalent new-user analyses

## Results and export

Functions for exporting results to CSV and uploading to a results
database compatible with Strategus and OhdsiShinyAppBuilder.

- [`exportToCsv()`](https://ob325.github.io/PrevalentNewUser/reference/exportToCsv.md)
  : Export analysis results to CSV files
- [`createResultsDataModel()`](https://ob325.github.io/PrevalentNewUser/reference/createResultsDataModel.md)
  : Create the PNU results data model in a database
- [`uploadResults()`](https://ob325.github.io/PrevalentNewUser/reference/uploadResults.md)
  : Upload analysis results to a database
