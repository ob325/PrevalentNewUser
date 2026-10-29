# Create the PNU results data model in a database

Reads the bundled results-data-model specification
(\`inst/csv/resultsDataModelSpecification.csv\`) and creates three
tables in the target database:

\* \`\<tablePrefix\>pnu_analysis\` — one row per analysis. \*
\`\<tablePrefix\>pnu_estimate\` — point estimate and CI per analysis. \*
\`\<tablePrefix\>pnu_covariate_balance\` — SMDs before and after
matching.

Existing tables with the same names are \*\*dropped and recreated\*\*.

## Usage

``` r
createResultsDataModel(connectionDetails, databaseSchema, tablePrefix = "pnu_")
```

## Arguments

- connectionDetails:

  A \`DatabaseConnector\` connectionDetails object.

- databaseSchema:

  Schema in which to create the tables.

- tablePrefix:

  Character prefix prepended to every table name. Default: \`"pnu\_"\`.
  Pass \`""\` to use bare table names.

## Value

\`NULL\` invisibly.

## See also

\[uploadResults()\]

## Examples

``` r
if (FALSE) { # \dontrun{
cd <- DatabaseConnector::createConnectionDetails(
  dbms   = "sqlite",
  server = tempfile(fileext = ".sqlite")
)
createResultsDataModel(cd, databaseSchema = "main")
} # }
```
