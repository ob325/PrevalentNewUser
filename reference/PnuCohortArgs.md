# Settings for identifying the PNU cohorts

Specifies which cohorts represent treatment A (reference), treatment B
(the new treatment / switcher index events), and the outcome, together
with covariate-filter and study-size options. Create with
\[createPnuCohortArgs()\].

## Super class

[`AbstractSerializableSettings`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.md)
-\> `PnuCohortArgs`

## Public fields

- `targetCohortId`:

  Cohort ID for treatment A (reference treatment).

- `comparatorCohortId`:

  Cohort ID for treatment B (switcher events).

- `outcomeCohortId`:

  Cohort ID for the outcome.

- `excludedCovariateConceptIds`:

  Concept IDs excluded from covariate construction.

- `includedCovariateConceptIds`:

  Concept IDs to include (empty = all).

- `washoutPeriod`:

  Days of observation required before cohort start.

- `maxCohortSize`:

  Maximum cohort size; 0 = no limit.

## Methods

### Public methods

- [`PnuCohortArgs$new()`](#method-PnuCohortArgs-initialize)

- [`PnuCohortArgs$validate()`](#method-PnuCohortArgs-validate)

Inherited methods

- [`AbstractSerializableSettings$toJson()`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.html#method-toJson)

------------------------------------------------------------------------

### `PnuCohortArgs$new()`

Construct from named arguments or a JSON string.

#### Usage

    PnuCohortArgs$new(
      targetCohortId = NULL,
      comparatorCohortId = NULL,
      outcomeCohortId = NULL,
      excludedCovariateConceptIds = integer(0),
      includedCovariateConceptIds = integer(0),
      washoutPeriod = 365L,
      maxCohortSize = 0L,
      json = NULL
    )

#### Arguments

- `targetCohortId, comparatorCohortId, outcomeCohortId`:

  Cohort IDs.

- `excludedCovariateConceptIds, includedCovariateConceptIds`:

  Integer vectors of concept IDs.

- `washoutPeriod`:

  Days of prior observation required.

- `maxCohortSize`:

  Maximum number of subjects per cohort (0 = no limit).

- `json`:

  JSON string from \`toJson()\`. When supplied all other arguments are
  ignored.

------------------------------------------------------------------------

### `PnuCohortArgs$validate()`

Validate all fields using checkmate.

#### Usage

    PnuCohortArgs$validate()
