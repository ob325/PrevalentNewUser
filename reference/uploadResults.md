# Upload analysis results to a database

Reads \`summary.csv\` and per-analysis \`.rds\` files from
\`resultsFolder\` (as produced by \[runPnuAnalyses()\]) and inserts the
data into the results tables created by \[createResultsDataModel()\].

## Usage

``` r
uploadResults(
  connectionDetails,
  databaseSchema,
  tablePrefix = "pnu_",
  resultsFolder
)
```

## Arguments

- connectionDetails:

  A \`DatabaseConnector\` connectionDetails object.

- databaseSchema:

  Schema containing the results tables.

- tablePrefix:

  Prefix used when the tables were created. Default: \`"pnu\_"\`.

- resultsFolder:

  Path to the folder produced by \[runPnuAnalyses()\].

## Value

\`NULL\` invisibly.

## Details

\`summary.csv\` supplies \`pnu_analysis\` (analysisId, description) and
\`pnu_estimate\` (point estimates, CIs, status). If the summary contains
calibrated-estimate columns (added by \[calibrateEstimates()\]), those
are also uploaded; otherwise the calibrated columns are \`NULL\`.

Each \`analysis\_\<id\>.rds\` is read for covariate balance data. If
\`result\$balance\` is non-\`NULL\`, rows are inserted into
\`pnu_covariate_balance\`.

Tables must already exist (call \[createResultsDataModel()\] first).

## See also

\[createResultsDataModel()\], \[runPnuAnalyses()\]

## Examples

``` r
if (FALSE) { # \dontrun{
cd <- DatabaseConnector::createConnectionDetails(
  dbms   = "sqlite",
  server = "results.sqlite"
)
createResultsDataModel(cd, databaseSchema = "main")
uploadResults(cd, databaseSchema = "main", resultsFolder = "output")
} # }
```
