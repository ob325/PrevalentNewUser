# Create covariate balance arguments

Specifies parameters for \[computeCovariateBalance()\].

## Usage

``` r
createBalanceArgs(maxCohortSizeForBalance = 250000L)
```

## Arguments

- maxCohortSizeForBalance:

  (\`integer(1)\`) Maximum number of persons per treatment arm used when
  computing means. If either arm exceeds this, it is randomly
  down-sampled before balance is assessed. \`0\` disables the limit.
  Default: \`250000\`.

## Value

A \`BalanceArgs\` R6 object.

## See also

\[computeCovariateBalance()\]

## Examples

``` r
balanceArgs <- createBalanceArgs()
balanceArgs <- createBalanceArgs(maxCohortSizeForBalance = 50000L)
```
