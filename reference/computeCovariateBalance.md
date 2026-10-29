# Compute covariate balance before and after matching

Computes the standardised mean difference (SMD) for each covariate
before matching (the full study population from
\[createStudyPopulation()\]) and after matching (the matched population
from \[matchOnTcps()\]).

## Usage

``` r
computeCovariateBalance(population, pnuData, balanceArgs)
```

## Arguments

- population:

  A data frame from \[matchOnTcps()\] containing at minimum \`row_id\`,
  \`treatment\`, and \`stratumId\`.

- pnuData:

  A \[PnuData\] object providing \`studyPopulation\`, \`covariates\`,
  and \`covariateRef\` tables.

- balanceArgs:

  A \`BalanceArgs\` object from \[createBalanceArgs()\].

## Value

A tibble with one row per covariate and columns:

- \`covariateId\`:

  Numeric covariate identifier.

- \`covariateName\`:

  Human-readable name from \`covariateRef\`.

- \`beforeMatchingMeanTarget\`:

  Weighted mean in switchers before matching.

- \`beforeMatchingMeanComparator\`:

  Weighted mean in comparators before matching.

- \`beforeMatchingSmd\`:

  SMD before matching.

- \`afterMatchingMeanTarget\`:

  Weighted mean in switchers after matching.

- \`afterMatchingMeanComparator\`:

  Weighted mean in comparators after matching.

- \`afterMatchingSmd\`:

  SMD after matching.

Rows are sorted by descending \`\|beforeMatchingSmd\|\`.

## Details

\*\*Before matching\*\* uses uniform per-arm weights (simple unweighted
means).

\*\*After matching\*\* uses stratum-size weights: each person in a
matched set of size \\n_s\\ receives weight \\1/n_s\\, then weights are
normalised to sum to 1 within each arm. This mirrors CohortMethod's
approach and gives equal influence to each matched set, regardless of
the number of comparators matched per switcher.

The SMD formula is \$\$SMD = \frac{\bar{x}\_1 -
\bar{x}\_0}{\sqrt{(\hat{p}\_1(1-\hat{p}\_1) +
\hat{p}\_0(1-\hat{p}\_0))/2}}\$\$ using the Bernoulli pooled variance of
the group means.

The "before" population is read from \`pnuData\$studyPopulation\`, which
is populated by \[createStudyPopulation()\] and is not modified by
\[matchOnTcps()\].

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## See also

\[createBalanceArgs()\], \[matchOnTcps()\], \[createStudyPopulation()\]

## Examples

``` r
if (FALSE) { # \dontrun{
simArgs <- createSimulationArgs(
  nSwitchers = 500L, nCovariates = 5L,
  prevalenceDiff = 0.3, seed = 1L
)
pnuData <- simulatePnuData(simArgs)
pnuData <- createStudyPopulation(pnuData, createStudyPopulationArgs(outcomeId = 1L))
pop <- dplyr::collect(pnuData$studyPopulation)
pop <- fitTcps(
  pop, pnuData,
  createTcpsArgs(
    prior = Cyclops::createPrior("normal", variance = 0.1),
    control = Cyclops::createControl(noiseLevel = "silent")
  )
)
matched <- matchOnTcps(pop, createMatchingArgs())
balance <- computeCovariateBalance(matched, pnuData, createBalanceArgs())
Andromeda::close(pnuData)
} # }
```
