# Load prevalent new-user study data from a database

Executes the exposure-set and cohort SQL against the CDM, calls
FeatureExtraction to collect covariates, queries the outcome cohort, and
returns a \[PnuData\] object containing all tables needed for downstream
analysis.

## Usage

``` r
getDbPnuData(
  connection,
  cdmDatabaseSchema,
  cohortDatabaseSchema,
  cohortTable,
  pnuCohortArgs,
  covariateSettings,
  tempEmulationSchema = NULL,
  exposureSetDefinition = "time",
  restrictToCommonPeriod = FALSE
)
```

## Arguments

- connection:

  A \`DatabaseConnector\` connection object.

- cdmDatabaseSchema:

  Schema containing the OMOP CDM tables.

- cohortDatabaseSchema:

  Schema containing \`cohortTable\`.

- cohortTable:

  Name of the cohort table (without schema prefix).

- pnuCohortArgs:

  A \[PnuCohortArgs\] settings object created by
  \[createPnuCohortArgs()\].

- covariateSettings:

  A covariate settings object created by
  \`FeatureExtraction::createCovariateSettings()\` or similar.

- tempEmulationSchema:

  Schema for temp-table emulation on databases that do not support
  native temp tables. Pass \`NULL\` on supported databases.

- exposureSetDefinition:

  \`"time"\` (days on treatment A) or \`"fills"\` (number of treatment-A
  eras). Default: \`"time"\`.

- restrictToCommonPeriod:

  Not yet implemented; reserved for future use.

## Value

A \[PnuData\] object.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## Examples

``` r
if (FALSE) { # \dontrun{
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sqlite", server = ":memory:"
)
conn <- DatabaseConnector::connect(connectionDetails)
pnuData <- getDbPnuData(
  connection           = conn,
  cdmDatabaseSchema    = "main",
  cohortDatabaseSchema = "main",
  cohortTable          = "cohort",
  pnuCohortArgs        = createPnuCohortArgs(
    targetCohortId = 1L, comparatorCohortId = 2L, outcomeCohortId = 3L
  ),
  covariateSettings    = FeatureExtraction::createDefaultCovariateSettings()
)
DatabaseConnector::disconnect(conn)
} # }
```
