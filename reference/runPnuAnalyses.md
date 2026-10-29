# Run a list of prevalent new-user analyses

Top-level orchestrator for the PNU pipeline. For each \[PnuAnalysis\] in
\`pnuAnalysisList\`, runs: study-population creation, TCPS fitting
(optional), greedy matching, optional covariate balance, outcome
modelling, and optional bootstrap CI. Per-analysis results are written
as RDS files; a summary CSV is written at the end.

## Usage

``` r
runPnuAnalyses(
  connectionDetails = NULL,
  cdmDatabaseSchema = NULL,
  cohortDatabaseSchema = NULL,
  cohortTable = NULL,
  covariateSettings = NULL,
  pnuAnalysisList,
  outputFolder,
  parallelComputing = FALSE,
  pnuDataList = NULL,
  tempEmulationSchema = NULL
)
```

## Arguments

- connectionDetails:

  A \`DatabaseConnector\` connectionDetails object. Required when
  \`pnuDataList\` is \`NULL\`.

- cdmDatabaseSchema:

  Schema containing the OMOP CDM tables.

- cohortDatabaseSchema:

  Schema containing \`cohortTable\`.

- cohortTable:

  Name of the cohort table (without schema prefix).

- covariateSettings:

  A covariate settings object from
  \`FeatureExtraction::createCovariateSettings()\`. Required when
  \`pnuDataList\` is \`NULL\`.

- pnuAnalysisList:

  A list of \[PnuAnalysis\] objects created by
  \[createPnuAnalysisArgs()\].

- outputFolder:

  Path to the folder where results are written. Created if it does not
  exist.

- parallelComputing:

  Logical. Reserved for future use; ignored.

- pnuDataList:

  A list of \[PnuData\] objects (one per element of \`pnuAnalysisList\`)
  used instead of loading from a database.

- tempEmulationSchema:

  Schema for temp-table emulation. Ignored when \`pnuDataList\` is
  provided.

## Value

A tibble with one row per analysis and columns \`analysis_id\`,
\`description\`, \`log_rr\`, \`se_log_rr\`, \`ci_95_lb\`, \`ci_95_ub\`,
\`status\`, returned invisibly. The same table is written to
\`outputFolder/summary.csv\`. Each analysis's full result (matched
population, outcome model, optional balance and bootstrap) is saved as
\`outputFolder/analysis\_\<id\>.rds\`.

## Details

When \`pnuDataList\` is \`NULL\`, the function opens a database
connection and calls \[getDbPnuData()\] for each analysis using that
analysis's \`pnuCohortArgs\`. When \`pnuDataList\` is provided (a list
of \[PnuData\] objects, one per analysis in the same order), the
database loading step is skipped. The \`pnuDataList\` path is primarily
intended for simulation studies and testing.

\*\*Note on reference semantics:\*\* \[createStudyPopulation()\]
modifies \`pnuData\` in place (Andromeda is a reference object). If the
same \`PnuData\` object appears more than once in \`pnuDataList\`, the
\`studyPopulation\` table will be overwritten by each successive
analysis. Use separate \`PnuData\` objects when analyses have different
study-population settings.

\`parallelComputing = TRUE\` is accepted but analyses always run
sequentially in this version; parallel support is planned.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## See also

\[createPnuAnalysisArgs()\], \[fitOutcomeModel()\], \[bootstrapCi()\]

## Examples

``` r
if (FALSE) { # \dontrun{
analyses <- list(
  createPnuAnalysisArgs(
    analysisId          = 1L,
    description         = "Primary analysis",
    pnuCohortArgs       = createPnuCohortArgs(1L, 2L, 3L),
    studyPopulationArgs = createStudyPopulationArgs(outcomeId = 1L),
    matchingArgs        = createMatchingArgs(),
    outcomeModelArgs    = createOutcomeModelArgs()
  )
)
summary <- runPnuAnalyses(
  connectionDetails    = myConnectionDetails,
  cdmDatabaseSchema    = "cdm",
  cohortDatabaseSchema = "results",
  cohortTable          = "cohort",
  covariateSettings    = FeatureExtraction::createDefaultCovariateSettings(),
  pnuAnalysisList      = analyses,
  outputFolder         = "output"
)
} # }
```
