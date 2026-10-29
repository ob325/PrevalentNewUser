# Test whether an object is a PnuData instance

Test whether an object is a PnuData instance

## Usage

``` r
isPnuData(x)
```

## Arguments

- x:

  Object to test.

## Value

\`TRUE\` if \`x\` inherits from \`PnuData\`, \`FALSE\` otherwise.

## Examples

``` r
if (FALSE) { # \dontrun{
pnuData <- getDbPnuData(...)
isPnuData(pnuData) # TRUE
isPnuData(list()) # FALSE
} # }
```
