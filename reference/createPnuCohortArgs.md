# Create PNU cohort arguments

Specifies which cohorts play the roles of reference treatment (A), new
treatment / switcher events (B), and outcome, along with covariate
filters and population-size limits.

## Usage

``` r
createPnuCohortArgs(
  targetCohortId,
  comparatorCohortId,
  outcomeCohortId,
  excludedCovariateConceptIds = integer(0),
  includedCovariateConceptIds = integer(0),
  washoutPeriod = 365,
  maxCohortSize = 0
)
```

## Arguments

- targetCohortId:

  (\`integer(1)\`) Cohort ID for treatment A (reference treatment;
  patients must be on this treatment before the index date).

- comparatorCohortId:

  (\`integer(1)\`) Cohort ID for treatment B (the new treatment;
  switcher index events are the start dates in this cohort).

- outcomeCohortId:

  (\`integer(1)\`) Cohort ID for the outcome of interest.

- excludedCovariateConceptIds:

  (\`integer\`) Concept IDs to exclude when constructing covariates
  (e.g. drugs directly on the causal pathway). Default: \`integer(0)\`
  (none excluded).

- includedCovariateConceptIds:

  (\`integer\`) Concept IDs to include when constructing covariates. An
  empty vector means all concepts are included. Default: \`integer(0)\`.

- washoutPeriod:

  (\`integer(1)\`) Minimum days of continuous observation required
  before a subject's cohort start date. Default: \`365\`.

- maxCohortSize:

  (\`integer(1)\`) Maximum number of subjects in each cohort. \`0\`
  means no limit. Default: \`0\`.

## Value

A \`PnuCohortArgs\` R6 object.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## Examples

``` r
args <- createPnuCohortArgs(
  targetCohortId = 1,
  comparatorCohortId = 2,
  outcomeCohortId = 3
)
```
