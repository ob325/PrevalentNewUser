# Create outcome model arguments

Specifies all parameters for \[fitOutcomeModel()\], which fits a
regression model for the outcome on the matched (or stratified) study
population.

## Usage

``` r
createOutcomeModelArgs(
  modelType = "cox",
  stratified = TRUE,
  useCovariates = FALSE,
  prior = NULL,
  control = NULL
)
```

## Arguments

- modelType:

  (\`character(1)\`) One of \`"cox"\` (default), \`"logistic"\`, or
  \`"poisson"\`.

- stratified:

  (\`logical(1)\`) Whether to stratify by \`stratumId\` (matched set).
  \`TRUE\` (default) uses conditional Cox / logistic / Poisson;
  \`FALSE\` fits an unconditional model. Stratification requires that
  \[matchOnTcps()\] has been run.

- useCovariates:

  (\`logical(1)\`) If \`TRUE\`, include all covariates from \`pnuData\`
  as additional adjusters in the outcome model (doubly-robust approach).
  Default: \`FALSE\`.

- prior:

  (\`cyclopsPrior\`) Cyclops prior for the covariate coefficients when
  \`useCovariates = TRUE\`. The treatment coefficient is always
  unpenalised. Ignored when \`useCovariates = FALSE\`. \`NULL\` uses a
  Laplace prior with cross-validation.

- control:

  (\`cyclopsControl\`) Cyclops control specification. \`NULL\` uses the
  Cyclops default.

## Value

An \`OutcomeModelArgs\` R6 object.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## Examples

``` r
if (FALSE) { # \dontrun{
# Default: stratified Cox, treatment effect only
outcomeModelArgs <- createOutcomeModelArgs()

# Doubly-robust: also adjust for covariates in the outcome model
outcomeModelArgs <- createOutcomeModelArgs(useCovariates = TRUE)
} # }
```
