# An S4 class for prevalent new-user study data

\`PnuData\` extends \`CovariateData\` (from FeatureExtraction) and is
the central data container passed between all analytical steps. Like
\`CovariateData\`, it is backed by an Andromeda (DuckDB) database and
holds its tables as database tables accessed via the \`\$\` operator,
not as S4 slots.

Core tables (in addition to the covariates / covariateRef / analysisRef
tables inherited from \`CovariateData\`):

\| Table \| Key columns \| \|—\|—\| \| \`cohorts\` \| \`row_id\`,
\`person_seq_id\`, \`person_id\`, \`cohort_start_date\`,
\`cohort_end_date\`, \`treatment\`, \`exposure_set_id\` \| \|
\`outcomes\` \| \`person_seq_id\`, \`outcome_id\`, \`outcome_date\` \|
\| \`exposureSets\` \| \`person_seq_id\`, \`exposure_set_id\`,
\`days_on_a\` \|

\`treatment\` = 1 for switchers (target), 0 for comparators.
\`exposure_set_id\` = 0 means no prior treatment A (equivalent to ACNU).

Create with \[createEmptyPnuData()\] (internal) or \[getDbPnuData()\]
(Step 3.1).

## Usage

``` r
# S4 method for class 'PnuData'
show(object)
```

## Arguments

- object:

  A \`PnuData\` object.

## Methods (by generic)

- `show(PnuData)`: Print a concise summary of a PnuData object.

## References

Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs
for comparative drug effect studies by time-conditional propensity
scores. \*Pharmacoepidemiol Drug Saf\* 2017;26(4):459-468.
[doi:10.1002/pds.4117](https://doi.org/10.1002/pds.4117)

## See also

\[isPnuData()\], \[getDbPnuData()\], \[savePnuData()\],
\[loadPnuData()\]
