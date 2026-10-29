# Fit an outcome model on the matched population

Fits a regression model for the outcome using Cyclops. By default, a
stratified Cox proportional-hazards model stratified by \`stratumId\`
(matched set) is used, which is the standard analysis for the prevalent
new-user design.

## Usage

``` r
fitOutcomeModel(population, pnuData = NULL, outcomeModelArgs)
```

## Arguments

- population:

  A data frame from \[matchOnTcps()\] containing \`row_id\`,
  \`treatment\`, \`stratumId\`, \`survival_time\`, and
  \`outcome_count\`.

- pnuData:

  A \[PnuData\] object. Required when \`useCovariates = TRUE\` (for
  \`covariates\` and \`covariateRef\` tables).

- outcomeModelArgs:

  An \`OutcomeModelArgs\` object from \[createOutcomeModelArgs()\].

## Value

A named list of class \`"OutcomeModel"\` with elements:

- \`logRr\`:

  Log hazard (or odds / rate) ratio for the treatment.

- \`seLogRr\`:

  Standard error of \`logRr\`, derived from the profile CI.

- \`p\`:

  Two-sided p-value.

- \`ci95Lb\`:

  Lower bound of the 95% confidence interval on the ratio scale.

- \`ci95Ub\`:

  Upper bound of the 95% confidence interval on the ratio scale.

- \`status\`:

  \`"OK"\` or a description of why the model could not be fit.

- \`outcomeModelType\`:

  Value of \`modelType\`.

- \`outcomeModelStratified\`:

  Value of \`stratified\`.

## Details

Only strata with at least one outcome event contribute to the stratified
model likelihood. Strata with zero events are dropped before fitting
(standard partial-likelihood behaviour).

The treatment estimate is the coefficient for the binary \`treatment\`
covariate. When \`useCovariates = FALSE\` (default), no other covariates
are included and no regularization is applied (\`prior = "none"\`). When
\`useCovariates = TRUE\`, all covariates from \`pnuData\$covariates\`
are included as additional adjusters; the treatment coefficient remains
unpenalised.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## See also

\[createOutcomeModelArgs()\], \[matchOnTcps()\]

## Examples

``` r
if (FALSE) { # \dontrun{
simArgs <- createSimulationArgs(
  nSwitchers = 500L, nCovariates = 0L,
  logRr = log(2), seed = 1L
)
pnuData <- simulatePnuData(simArgs)
pnuData <- createStudyPopulation(pnuData, createStudyPopulationArgs(outcomeId = 1L))
pop <- dplyr::collect(pnuData$studyPopulation)
pop$propensityScore <- 0.5
matched <- matchOnTcps(pop, createMatchingArgs())
result <- fitOutcomeModel(matched, pnuData, createOutcomeModelArgs())
Andromeda::close(pnuData)
} # }
```
