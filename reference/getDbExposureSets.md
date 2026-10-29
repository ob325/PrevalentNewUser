# Compute exposure sets on a database server

Executes \`GetExposureSets.sql\` against a database cohort table and
returns the result as a tibble. The output schema matches
\[computeExposureSetsInR()\].

Observation-period eligibility is \*\*not\*\* checked here; that filter
is applied in \[createStudyPopulation()\].

## Usage

``` r
getDbExposureSets(
  connection,
  cohortDatabaseSchema,
  cohortTable,
  targetCohortId,
  comparatorCohortId,
  tempEmulationSchema = NULL,
  exposureSetDefinition = "time"
)
```

## Arguments

- connection:

  A \`DatabaseConnector\` connection object.

- cohortDatabaseSchema:

  Schema name that contains \`cohortTable\`.

- cohortTable:

  Name of the cohort table (without schema prefix).

- targetCohortId:

  (\`integer(1)\`) Cohort ID for treatment A.

- comparatorCohortId:

  (\`integer(1)\`) Cohort ID for treatment B (switchers).

- tempEmulationSchema:

  Schema for temp-table emulation on databases that do not support
  native temp tables (e.g. Oracle, BigQuery). Pass \`NULL\` on supported
  databases.

- exposureSetDefinition:

  \`"time"\` (days on A) or \`"fills"\` (A era count). Default:
  \`"time"\`.

## Value

A \[dplyr::tibble()\] with columns \`person_id\` (character),
\`exposure_set\` (integer), \`index_date\` (Date), \`is_switcher\`
(logical).

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## Examples

``` r
if (FALSE) { # \dontrun{
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sqlite",
  server = ":memory:"
)
conn <- DatabaseConnector::connect(connectionDetails)
es <- getDbExposureSets(
  connection = conn,
  cohortDatabaseSchema = "main",
  cohortTable = "cohort",
  targetCohortId = 1L,
  comparatorCohortId = 2L
)
DatabaseConnector::disconnect(conn)
} # }
```
