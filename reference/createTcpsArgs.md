# Create TCPS fitting arguments

Specifies all parameters for \[fitTcps()\], which fits a conditional
logistic regression (CLR) stratified by exposure set.

## Usage

``` r
createTcpsArgs(
  prior = NULL,
  control = NULL,
  excludedCovariateConceptIds = integer(0),
  includedCovariateConceptIds = integer(0),
  maxCohortSizeForFitting = 250000L,
  seed = 1L
)
```

## Arguments

- prior:

  (\`cyclopsPrior\`) A Cyclops prior object created with
  \`Cyclops::createPrior()\`. Defaults to a Laplace (LASSO) prior with
  cross-validation: \`Cyclops::createPrior("laplace", variance = 0.01,
  useCrossValidation = TRUE)\`.

- control:

  (\`cyclopsControl\`) A Cyclops control object created with
  \`Cyclops::createControl()\`. Defaults to
  \`Cyclops::createControl(noiseLevel = "silent", cvType = "auto", fold
  = 10, startingVariance = 0.01, seed = 1L)\`.

- excludedCovariateConceptIds:

  (\`integer\`) Concept IDs to exclude from the CLR (e.g. drugs on the
  causal pathway). Default: \`integer(0)\`.

- includedCovariateConceptIds:

  (\`integer\`) Concept IDs to include. Empty means all. Default:
  \`integer(0)\`.

- maxCohortSizeForFitting:

  (\`integer(1)\`) Maximum number of persons per treatment arm used for
  fitting. Persons beyond this limit are randomly sampled out. \`0\`
  means no limit. Default: \`250000\`.

- seed:

  (\`integer(1)\`) RNG seed used when downsampling the cohort. Default:
  \`1\`.

## Value

A \`TcpsArgs\` R6 object.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## Examples

``` r
if (FALSE) { # \dontrun{
# Default settings (Laplace prior with cross-validation)
tcpsArgs <- createTcpsArgs()

# Fast fitting for testing (fixed variance, no cross-validation)
tcpsArgs <- createTcpsArgs(
  prior   = Cyclops::createPrior("normal", variance = 0.1),
  control = Cyclops::createControl(noiseLevel = "silent")
)
} # }
```
