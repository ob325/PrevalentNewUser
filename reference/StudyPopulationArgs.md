# Settings for study population creation

Holds all parameters controlling \[createStudyPopulation()\]. Create
with \[createStudyPopulationArgs()\].

## Super class

[`AbstractSerializableSettings`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.md)
-\> `StudyPopulationArgs`

## Public fields

- `outcomeId`:

  Outcome cohort ID to index the study population on.

- `firstExposureOnly`:

  Keep only the earliest cohort entry per person per arm.

- `washoutPeriod`:

  Minimum days of prior observation required.

- `removeDuplicateSubjects`:

  How to handle persons in both arms.

- `priorOutcomeLookback`:

  Exclude persons with outcome in this many days before index.

- `requireTimeAtRisk`:

  Require at least minDaysAtRisk days in the risk window.

- `minDaysAtRisk`:

  Minimum days at risk (when requireTimeAtRisk is TRUE).

- `maxDaysAtRisk`:

  Maximum days at risk; outcomes after this are ignored. 99999 = no cap.

- `riskWindowStart`:

  Days from startAnchor to the start of the risk window.

- `riskWindowEnd`:

  Days from endAnchor to the end of the risk window.

- `startAnchor`:

  Anchor for riskWindowStart: "cohort start" or "cohort end".

- `endAnchor`:

  Anchor for riskWindowEnd: "cohort start" or "cohort end".

- `censorAtNewRiskWindow`:

  Censor subjects when they start a new risk window.

## Methods

### Public methods

- [`StudyPopulationArgs$new()`](#method-StudyPopulationArgs-initialize)

- [`StudyPopulationArgs$validate()`](#method-StudyPopulationArgs-validate)

Inherited methods

- [`AbstractSerializableSettings$toJson()`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.html#method-toJson)

------------------------------------------------------------------------

### `StudyPopulationArgs$new()`

Construct from named arguments or a JSON string.

#### Usage

    StudyPopulationArgs$new(
      outcomeId = NULL,
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
      censorAtNewRiskWindow = FALSE,
      json = NULL
    )

#### Arguments

- `outcomeId, firstExposureOnly, washoutPeriod, removeDuplicateSubjects`:

  See factory.

- `priorOutcomeLookback, requireTimeAtRisk, minDaysAtRisk, maxDaysAtRisk`:

  See factory.

- `riskWindowStart, riskWindowEnd, startAnchor, endAnchor, censorAtNewRiskWindow`:

  See factory.

- `json`:

  JSON string from \`toJson()\`. When supplied, all other arguments are
  ignored.

------------------------------------------------------------------------

### `StudyPopulationArgs$validate()`

Validate all fields using checkmate.

#### Usage

    StudyPopulationArgs$validate()
