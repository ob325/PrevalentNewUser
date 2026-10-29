# Create simulation arguments

Specifies the population and outcome parameters for
\[simulatePnuData()\]. The simulated \`PnuData\` has a known treatment
effect (\`logRr\`) and a controllable covariate structure for testing
statistical steps without a real database.

\*\*Data-generating process\*\*

Each exposure set contains \`nSwitchers\` switchers and
\`nComparatorsPerSet\` comparators. Covariates are binary: P(covariate
= 1) = \`prevalenceBase\` for comparators and \`min(1, prevalenceBase +
prevalenceDiff)\` for switchers (covariates predict treatment but not
the outcome, so the crude rate ratio equals \`exp(logRr)\`
asymptotically). Outcome times follow an exponential model with baseline
hazard chosen so that comparators have exactly \`outcomeBaseRate\`
probability of an event in \`followUpDays\` days.

## Usage

``` r
createSimulationArgs(
  nSwitchers = 200L,
  nComparatorsPerSet = 200L,
  nExposureSets = 3L,
  nCovariates = 10L,
  prevalenceBase = 0.2,
  prevalenceDiff = 0.1,
  outcomeBaseRate = 0.05,
  followUpDays = 365L,
  logRr = 0,
  seed = 1L,
  json = NULL
)
```

## Arguments

- nSwitchers:

  (\`integer(1)\`) Number of switchers per exposure set. Default:
  \`200\`.

- nComparatorsPerSet:

  (\`integer(1)\`) Number of comparators per exposure set. Default:
  \`200\`.

- nExposureSets:

  (\`integer(1)\`) Number of exposure sets. Set \`1\` for a pure
  ACNU-equivalent simulation. Default: \`3\`.

- nCovariates:

  (\`integer(1)\`) Number of simulated binary covariates. \`0\`
  generates no covariates. Default: \`10\`.

- prevalenceBase:

  (\`numeric(1)\`) Baseline covariate prevalence in comparators. Must be
  in \\0, 1\\. Default: \`0.2\`.

- prevalenceDiff:

  (\`numeric(1)\`) Additional covariate prevalence in switchers
  (confounding by indication). Must be in \\0, 1\\. Default: \`0.1\`.

- outcomeBaseRate:

  (\`numeric(1)\`) Probability of the outcome within \`followUpDays\`
  for a comparator. Must be in (0, 1). Default: \`0.05\`.

- followUpDays:

  (\`integer(1)\`) Follow-up period in days. Default: \`365\`.

- logRr:

  (\`numeric(1)\`) True log hazard ratio for switchers relative to
  comparators. \`0\` means no treatment effect. Default: \`0\`.

- seed:

  (\`integer(1)\`) RNG seed for reproducibility. Default: \`1\`.

- json:

  (\`character(1)\`) JSON string from \`toJson()\`. When supplied, all
  other arguments are ignored and values are restored from JSON.

## Value

A \`SimulationArgs\` R6 object.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## Examples

``` r
args <- createSimulationArgs(
  nSwitchers = 500L,
  nExposureSets = 2L,
  logRr = log(2),
  seed = 1L
)
```
