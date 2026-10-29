# Create study population arguments

Specifies the outcome and inclusion/exclusion criteria for
\[createStudyPopulation()\].

## Usage

``` r
createStudyPopulationArgs(
  outcomeId,
  firstExposureOnly = FALSE,
  washoutPeriod = 0L,
  removeDuplicateSubjects = "keep all",
  priorOutcomeLookback = 0L,
  requireTimeAtRisk = TRUE,
  minDaysAtRisk = 1L,
  maxDaysAtRisk = 99999L,
  riskWindowStart = 0L,
  riskWindowEnd = 0L,
  startAnchor = "cohort start",
  endAnchor = "cohort end",
  censorAtNewRiskWindow = FALSE
)
```

## Arguments

- outcomeId:

  (\`integer(1)\`) Cohort ID of the outcome of interest.

- firstExposureOnly:

  (\`logical(1)\`) If \`TRUE\`, keep only the earliest cohort entry per
  person per treatment arm. Default: \`FALSE\`.

- washoutPeriod:

  (\`integer(1)\`) Minimum days of prior observation required. Applied
  only when the \`cohorts\` table includes
  \`observation_period_start_date\`; silently skipped otherwise.
  Default: \`0\`.

- removeDuplicateSubjects:

  (\`character(1)\`) How to handle persons who appear in both the
  switcher and comparator arms: \`"keep all"\` (default), \`"keep
  first"\` (one row per person, earliest index date), or \`"remove
  all"\` (exclude all such persons).

- priorOutcomeLookback:

  (\`integer(1)\`) Exclude persons who had the outcome within this many
  days before their index date. \`0\` means no exclusion. Default:
  \`0\`.

- requireTimeAtRisk:

  (\`logical(1)\`) If \`TRUE\`, exclude persons who have fewer than
  \`minDaysAtRisk\` days in their risk window. Default: \`TRUE\`.

- minDaysAtRisk:

  (\`integer(1)\`) Minimum days at risk required when
  \`requireTimeAtRisk\` is \`TRUE\`. Default: \`1\`.

- maxDaysAtRisk:

  (\`integer(1)\`) Cap the follow-up at this many days. Outcomes
  occurring after the cap are not counted. \`99999\` means no cap.
  Default: \`99999\`.

- riskWindowStart:

  (\`integer(1)\`) Days from \`startAnchor\` to the start of the risk
  window. Default: \`0\`.

- riskWindowEnd:

  (\`integer(1)\`) Days from \`endAnchor\` to the end of the risk
  window. Default: \`0\`.

- startAnchor:

  (\`character(1)\`) The date to which \`riskWindowStart\` is added:
  \`"cohort start"\` (index date) or \`"cohort end"\`. Default:
  \`"cohort start"\`.

- endAnchor:

  (\`character(1)\`) The date to which \`riskWindowEnd\` is added:
  \`"cohort start"\` (index date) or \`"cohort end"\`. Default:
  \`"cohort end"\`.

- censorAtNewRiskWindow:

  (\`logical(1)\`) Reserved for future use. Default: \`FALSE\`.

## Value

A \`StudyPopulationArgs\` R6 object.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## Examples

``` r
args <- createStudyPopulationArgs(
  outcomeId = 3L,
  requireTimeAtRisk = TRUE,
  minDaysAtRisk = 1L,
  riskWindowStart = 0L,
  riskWindowEnd = 365L,
  endAnchor = "cohort start"
)
```
