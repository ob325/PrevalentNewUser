# Settings for PNU simulation

Holds all parameters controlling \[simulatePnuData()\]. Create with
\[createSimulationArgs()\].

## Super class

[`AbstractSerializableSettings`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.md)
-\> `SimulationArgs`

## Public fields

- `nSwitchers`:

  Switchers per exposure set.

- `nComparatorsPerSet`:

  Comparators per exposure set.

- `nExposureSets`:

  Number of exposure sets.

- `nCovariates`:

  Number of simulated binary covariates.

- `prevalenceBase`:

  Baseline covariate prevalence in comparators.

- `prevalenceDiff`:

  Additional covariate prevalence in switchers.

- `outcomeBaseRate`:

  Outcome probability in comparators over the follow-up.

- `followUpDays`:

  Follow-up duration in days.

- `logRr`:

  True log hazard ratio (switchers vs. comparators).

- `seed`:

  Integer seed for reproducibility.

## Methods

### Public methods

- [`SimulationArgs$new()`](#method-SimulationArgs-initialize)

- [`SimulationArgs$validate()`](#method-SimulationArgs-validate)

Inherited methods

- [`AbstractSerializableSettings$toJson()`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.html#method-toJson)

------------------------------------------------------------------------

### `SimulationArgs$new()`

Construct from named arguments or a JSON string.

#### Usage

    SimulationArgs$new(
      nSwitchers = 200L,
      nComparatorsPerSet = 200L,
      nExposureSets = 3L,
      nCovariates = 10L,
      prevalenceBase = 0.2,
      prevalenceDiff = 0.1,
      outcomeBaseRate = 0.05,
      followUpDays = 365L,
      logRr = 0,
      seed = 1L,
      json = NULL
    )

#### Arguments

- `nSwitchers, nComparatorsPerSet, nExposureSets, nCovariates`:

  Population parameters.

- `prevalenceBase, prevalenceDiff`:

  Covariate prevalence parameters.

- `outcomeBaseRate, followUpDays, logRr`:

  Outcome parameters.

- `seed`:

  Integer RNG seed.

- `json`:

  JSON string from \`toJson()\`. When supplied, all other arguments are
  ignored.

------------------------------------------------------------------------

### `SimulationArgs$validate()`

Validate all fields using checkmate.

#### Usage

    SimulationArgs$validate()
