# Compute exposure sets in pure R (reference implementation)

Assigns every switcher and every eligible comparator to one or more
exposure sets, returning a single data frame that the SQL implementation
(Step 2.2) must reproduce exactly on the same input.

\*\*Switchers\*\* are all persons present in \`treatmentB\`. Their
exposure set is determined by their history of treatment A on the day
they started B.

\*\*Comparators\*\* are persons present in \`treatmentA\` who are
\*not\* switchers. For each exposure set E that exists among the
switchers, a comparator is eligible if and only if: 1. They reached
exposure-set E in their own A history (i.e. a candidate index date
exists), AND 2. They were still on treatment A on that candidate index
date, AND 3. They were within their observation period on that date.

A comparator can appear in multiple rows (one per exposure set they are
eligible for). Exposure set 0 (no prior A) is supported for
\*\*switchers\*\* only; comparator identification for set 0 requires
calendar-date matching that is handled in the study-population step.

## Usage

``` r
computeExposureSetsInR(
  treatmentA,
  treatmentB,
  observationPeriod,
  exposureSetDefinition = "time"
)
```

## Arguments

- treatmentA:

  Data frame — treatment A (reference) cohort. Required columns:
  \`subject_id\`, \`cohort_start_date\`, \`cohort_end_date\`.

- treatmentB:

  Data frame — treatment B (switcher) cohort. Required columns:
  \`subject_id\`, \`cohort_start_date\`.

- observationPeriod:

  Data frame — OMOP observation_period. Required columns: \`person_id\`,
  \`observation_period_start_date\`, \`observation_period_end_date\`.

- exposureSetDefinition:

  \`"time"\` (days on A) or \`"fills"\` (number of A eras started before
  the switch). Default: \`"time"\`.

## Value

A data frame with one row per (person, exposure-set) pair:

- \`person_id\`:

  Character person identifier.

- \`exposure_set\`:

  Integer exposure-set identifier (0 = no prior A).

- \`index_date\`:

  Date index date for this row.

- \`is_switcher\`:

  Logical — \`TRUE\` for switchers, \`FALSE\` for comparators.
