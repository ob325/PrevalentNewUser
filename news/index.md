# Changelog

## PrevalentNewUser 0.0.1

Initial release implementing the prevalent new-user (PNU) cohort design
for OMOP CDM data.

### New functions

**Data**

- [`createPnuCohortArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createPnuCohortArgs.md)
  — specify target, comparator, and outcome cohort IDs
- [`getDbPnuData()`](https://ob325.github.io/PrevalentNewUser/reference/getDbPnuData.md)
  — pull cohorts, covariates, and exposure sets from a CDM database
- [`loadPnuData()`](https://ob325.github.io/PrevalentNewUser/reference/loadPnuData.md)
  /
  [`savePnuData()`](https://ob325.github.io/PrevalentNewUser/reference/savePnuData.md)
  — persist `PnuData` objects to disk

**Simulation**

- [`createSimulationArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createSimulationArgs.md)
  /
  [`simulatePnuData()`](https://ob325.github.io/PrevalentNewUser/reference/simulatePnuData.md)
  — generate synthetic PNU data with a known true effect for testing and
  method development

**Pipeline**

- [`createStudyPopulationArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createStudyPopulationArgs.md)
  /
  [`createStudyPopulation()`](https://ob325.github.io/PrevalentNewUser/reference/createStudyPopulation.md)
  — apply eligibility criteria and define risk windows
- [`createTcpsArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createTcpsArgs.md)
  /
  [`fitTcps()`](https://ob325.github.io/PrevalentNewUser/reference/fitTcps.md)
  — estimate time-conditional propensity scores by conditional logistic
  regression (Cyclops)
- [`createMatchingArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createMatchingArgs.md)
  /
  [`matchOnTcps()`](https://ob325.github.io/PrevalentNewUser/reference/matchOnTcps.md)
  — nearest-neighbour matching within exposure sets
- `createCovariateBalanceArgs()` /
  [`computeCovariateBalance()`](https://ob325.github.io/PrevalentNewUser/reference/computeCovariateBalance.md)
  — standardised mean differences before and after matching
- [`createOutcomeModelArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createOutcomeModelArgs.md)
  /
  [`fitOutcomeModel()`](https://ob325.github.io/PrevalentNewUser/reference/fitOutcomeModel.md)
  — stratified Cox proportional-hazards model
- [`createBootstrapArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createBootstrapArgs.md)
  /
  [`bootstrapCi()`](https://ob325.github.io/PrevalentNewUser/reference/bootstrapCi.md)
  — stratum-resampling bootstrap confidence interval

**Orchestration & calibration**

- [`createPnuAnalysisArgs()`](https://ob325.github.io/PrevalentNewUser/reference/createPnuAnalysisArgs.md)
  /
  [`runPnuAnalyses()`](https://ob325.github.io/PrevalentNewUser/reference/runPnuAnalyses.md)
  — top-level orchestrator for multi-analysis studies
- [`calibrateEstimates()`](https://ob325.github.io/PrevalentNewUser/reference/calibrateEstimates.md)
  — empirical calibration of p-values and confidence intervals using
  negative controls

**Results**

- [`createResultsDataModel()`](https://ob325.github.io/PrevalentNewUser/reference/createResultsDataModel.md)
  — create results tables in a database
- [`uploadResults()`](https://ob325.github.io/PrevalentNewUser/reference/uploadResults.md)
  — upload analysis results to the results tables
- [`exportToCsv()`](https://ob325.github.io/PrevalentNewUser/reference/exportToCsv.md)
  — export results as flat CSV files for Strategus / Shiny aggregation
