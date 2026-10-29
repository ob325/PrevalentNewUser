# PrevalentNewUser 0.0.1

Initial release implementing the prevalent new-user (PNU) cohort design for OMOP CDM data.

## New functions

**Data**

- `createPnuCohortArgs()` — specify target, comparator, and outcome cohort IDs
- `getDbPnuData()` — pull cohorts, covariates, and exposure sets from a CDM database
- `loadPnuData()` / `savePnuData()` — persist `PnuData` objects to disk

**Simulation**

- `createSimulationArgs()` / `simulatePnuData()` — generate synthetic PNU data with a known true effect for testing and method development

**Pipeline**

- `createStudyPopulationArgs()` / `createStudyPopulation()` — apply eligibility criteria and define risk windows
- `createTcpsArgs()` / `fitTcps()` — estimate time-conditional propensity scores by conditional logistic regression (Cyclops)
- `createMatchingArgs()` / `matchOnTcps()` — nearest-neighbour matching within exposure sets
- `createCovariateBalanceArgs()` / `computeCovariateBalance()` — standardised mean differences before and after matching
- `createOutcomeModelArgs()` / `fitOutcomeModel()` — stratified Cox proportional-hazards model
- `createBootstrapArgs()` / `bootstrapCi()` — stratum-resampling bootstrap confidence interval

**Orchestration & calibration**

- `createPnuAnalysisArgs()` / `runPnuAnalyses()` — top-level orchestrator for multi-analysis studies
- `calibrateEstimates()` — empirical calibration of p-values and confidence intervals using negative controls

**Results**

- `createResultsDataModel()` — create results tables in a database
- `uploadResults()` — upload analysis results to the results tables
- `exportToCsv()` — export results as flat CSV files for Strategus / Shiny aggregation
