# Load a PnuData object from disk

Restores a \[PnuData\] object previously written by \[savePnuData()\].

## Usage

``` r
loadPnuData(file)
```

## Arguments

- file:

  Path to the zip file produced by \[savePnuData()\].

## Value

A \[PnuData\] object.

## See also

\[savePnuData()\]

## Examples

``` r
if (FALSE) { # \dontrun{
pnuData <- loadPnuData("pnuData.zip")
} # }
```
