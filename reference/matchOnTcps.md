# Match on the time-conditional propensity score

Performs greedy nearest-neighbour matching of switchers to comparators
within each exposure set using the \`propensityScore\` column produced
by \[fitTcps()\]. Unmatched persons are dropped. Returns the matched
population with a new \`stratumId\` column that identifies each matched
set (used as the stratum in outcome models).

## Usage

``` r
matchOnTcps(population, matchingArgs)
```

## Arguments

- population:

  A data frame (typically \`dplyr::collect(pnuData\$studyPopulation)\`)
  with a \`propensityScore\` column added by \[fitTcps()\]. Must contain
  \`row_id\`, \`treatment\`, \`exposure_set_id\`, and
  \`propensityScore\`.

- matchingArgs:

  A \`MatchingArgs\` object from \[createMatchingArgs()\].

## Value

\`population\` filtered to matched persons and with an additional
integer \`stratumId\` column. Each stratum contains exactly one switcher
and one to \`maxRatio\` comparators (or all within-caliper comparators
when \`maxRatio = 0\`).

## Details

The caliper is computed once across all exposure sets. When
\`caliperScale = "standardized logit"\` (default), the caliper width is
\`caliper \* SD(logit(PS))\` pooled across the full population. This
mirrors CohortMethod's behaviour.

Within each exposure set, cases (switchers, \`treatment = 1\`) are
processed in ascending PS order. For each case, all available
comparators within the caliper are identified; the nearest (up to
\`maxRatio\`) are selected and assigned the same stratum ID. Stratum IDs
are unique integers across the whole returned population.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## See also

\[createMatchingArgs()\], \[fitTcps()\]

## Examples

``` r
if (FALSE) { # \dontrun{
simArgs <- createSimulationArgs(nSwitchers = 500L, nCovariates = 5L, seed = 1L)
pnuData <- simulatePnuData(simArgs)
spArgs <- createStudyPopulationArgs(outcomeId = 1L)
pnuData <- createStudyPopulation(pnuData, spArgs)
pop <- dplyr::collect(pnuData$studyPopulation)
tcpsArgs <- createTcpsArgs(
  prior   = Cyclops::createPrior("normal", variance = 0.1),
  control = Cyclops::createControl(noiseLevel = "silent")
)
pop <- fitTcps(pop, pnuData, tcpsArgs)
matchingArgs <- createMatchingArgs(caliper = 0.2, maxRatio = 1L)
matched <- matchOnTcps(pop, matchingArgs)
Andromeda::close(pnuData)
} # }
```
