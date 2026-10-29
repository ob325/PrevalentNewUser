# Bootstrap confidence intervals for the treatment effect

Estimates confidence intervals for the treatment log hazard (or odds /
rate) ratio using case-resampling bootstrap. Matched sets (strata
identified by \`stratumId\`) are resampled with replacement, preserving
the matched structure. The outcome model is refit on each resample.

## Usage

``` r
bootstrapCi(population, pnuData = NULL, outcomeModelArgs, bootstrapArgs)
```

## Arguments

- population:

  A data frame from \[matchOnTcps()\] with a \`stratumId\` column.

- pnuData:

  A \[PnuData\] object, or \`NULL\` when
  \`outcomeModelArgs\$useCovariates = FALSE\`.

- outcomeModelArgs:

  An \`OutcomeModelArgs\` object from \[createOutcomeModelArgs()\].

- bootstrapArgs:

  A \`BootstrapArgs\` object from \[createBootstrapArgs()\].

## Value

A named list with elements:

- \`logRr\`:

  Log ratio from the full-data model.

- \`seLogRr\`:

  Bootstrap standard error of \`logRr\`.

- \`ci95Lb\`:

  Lower 95% bootstrap percentile CI on the ratio scale.

- \`ci95Ub\`:

  Upper 95% bootstrap percentile CI on the ratio scale.

- \`numberOfBootstraps\`:

  Number of successful replications used.

- \`status\`:

  \`"OK"\` or description of failure.

## Details

The original point estimate (\`logRr\`) is the value from fitting
\[fitOutcomeModel()\] on the full (unbootstrapped) matched population.
The \`seLogRr\` is the standard deviation of the bootstrap distribution
of \`logRr\`. The \`ci95Lb\` and \`ci95Ub\` are 2.5th and 97.5th
percentiles of the bootstrap distribution (percentile method).

Replications for which the outcome model fails to converge (e.g. strata
with no events after resampling) are dropped and a message is issued.

Parallel execution (\`cores \> 1\`) uses \`parallel::mclapply\` and is
only available on Unix/macOS. On Windows it falls back to sequential
execution silently.

\*\*Note:\*\* This function can be slow. For \`numberOfReplications =
1000\` and large populations, run time may be several minutes. Full
production runs are best placed in \`extras/\` scripts rather than in
the test suite.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## See also

\[createBootstrapArgs()\], \[fitOutcomeModel()\], \[matchOnTcps()\]

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
bootstrapArgs <- createBootstrapArgs(numberOfReplications = 200L, seed = 1L)
result <- bootstrapCi(matched, NULL, createOutcomeModelArgs(), bootstrapArgs)
Andromeda::close(pnuData)
} # }
```
