# Create a study population from a PnuData object

Filters the cohort data in \`pnuData\` for a specific outcome and
applies inclusion/exclusion criteria specified in
\`studyPopulationArgs\`. The resulting \`studyPopulation\` table is
written into \`pnuData\` (Andromeda is a reference object, so the
original is modified in place) and the same object is returned.

The \`studyPopulation\` table adds \`survival_time\`, \`outcome_count\`,
and \`days_to_event\` columns to the cohort rows. These are used by all
downstream steps (TCPS, matching, outcome models).

## Usage

``` r
createStudyPopulation(pnuData, studyPopulationArgs)
```

## Arguments

- pnuData:

  A \[PnuData\] object from \[getDbPnuData()\] or \[simulatePnuData()\].

- studyPopulationArgs:

  A \`StudyPopulationArgs\` object from \[createStudyPopulationArgs()\].

## Value

The same \`pnuData\` object with \`pnuData\$studyPopulation\` populated.
The returned object is the same reference as the input; the caller does
not need to capture the return value.

## Details

\*\*Risk window\*\* The at-risk period for each person runs from
\`startAnchor + riskWindowStart\` to \`min(endAnchor + riskWindowEnd,
cohort_end_date)\`. \`survival_time\` is the number of days from the
risk window start to the first outcome or the end of follow-up,
whichever comes first.

\*\*washoutPeriod\*\* Applied only when the \`cohorts\` table contains
an \`observation_period_start_date\` column. In simulated data (from
\[simulatePnuData()\]) that column is absent; a \`washoutPeriod \> 0\`
is silently skipped with a message.

\*\*censorAtNewRiskWindow\*\* Stored in \`studyPopulationArgs\` but not
yet implemented; a warning is issued when set to \`TRUE\`.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## See also

\[createStudyPopulationArgs()\], \[simulatePnuData()\],
\[getDbPnuData()\]

## Examples

``` r
if (FALSE) { # \dontrun{
simArgs <- createSimulationArgs(nSwitchers = 200L, seed = 1L)
pnuData <- simulatePnuData(simArgs)
spArgs <- createStudyPopulationArgs(outcomeId = 1L)
pnuData <- createStudyPopulation(pnuData, spArgs)
sp <- dplyr::collect(pnuData$studyPopulation)
Andromeda::close(pnuData)
} # }
```
