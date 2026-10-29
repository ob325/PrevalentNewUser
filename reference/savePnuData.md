# Save a PnuData object to disk

Serialises all Andromeda tables (including covariates) to a zip file.
R-level attributes such as \`metaData\` are preserved because Andromeda
persists them alongside the DuckDB database.

## Usage

``` r
savePnuData(pnuData, file)
```

## Arguments

- pnuData:

  A \[PnuData\] object.

- file:

  Path to the output zip file.

## Value

\`NULL\` invisibly.

## See also

\[loadPnuData()\]

## Examples

``` r
if (FALSE) { # \dontrun{
savePnuData(pnuData, "pnuData.zip")
pnuData2 <- loadPnuData("pnuData.zip")
} # }
```
