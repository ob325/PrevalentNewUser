# Export analysis results to CSV files

Reads \`summary.csv\` and per-analysis \`.rds\` files produced by
\[runPnuAnalyses()\] and writes three flat CSV files to \`exportFolder\`
whose column names match the results data model specification:

\* \`analysis.csv\` — one row per analysis. \* \`estimate.csv\` — point
estimate and CI per analysis; calibrated columns are included when
present in \`summary.csv\` (i.e. after \[calibrateEstimates()\] has been
applied), otherwise filled with \`NA\`. \* \`covariate_balance.csv\` —
covariate balance rows; omitted when no analysis produced balance data.

Every file receives a leading \`database_id\` column so that exports
from multiple databases can be stacked for use with Strategus or a Shiny
results viewer.

## Usage

``` r
exportToCsv(outputFolder, exportFolder, databaseId, minCellCount = 5L)
```

## Arguments

- outputFolder:

  Path to the folder produced by \[runPnuAnalyses()\]. Must contain
  \`summary.csv\`.

- exportFolder:

  Path to the folder where CSV files are written. Created if it does not
  exist.

- databaseId:

  Character string identifying the source database. Written as the first
  column of every exported file.

- minCellCount:

  Minimum allowable cell count; reserved for future small-cell
  suppression. Default: \`5L\`.

## Value

\`NULL\` invisibly.

## Details

\`minCellCount\` is accepted for forward compatibility; the current data
model stores log-scale estimates and proportions rather than raw counts,
so no rows are suppressed at present.

## See also

\[runPnuAnalyses()\], \[calibrateEstimates()\], \[uploadResults()\]

## Examples

``` r
if (FALSE) { # \dontrun{
runPnuAnalyses(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = "cdm",
  cohortDatabaseSchema = "cohorts",
  cohortTable = "cohort",
  covariateSettings = covariateSettings,
  pnuAnalysisList = analysisList,
  outputFolder = "output"
)
exportToCsv(
  outputFolder = "output",
  exportFolder = "export",
  databaseId   = "Synpuf"
)
} # }
```
