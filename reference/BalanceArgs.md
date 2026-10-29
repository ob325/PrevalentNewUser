# Settings for covariate balance computation

Holds parameters controlling \[computeCovariateBalance()\]. Create with
\[createBalanceArgs()\].

## Super class

[`AbstractSerializableSettings`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.md)
-\> `BalanceArgs`

## Public fields

- `maxCohortSizeForBalance`:

  Maximum persons per arm used when computing SMDs. Larger populations
  are randomly sampled. \`0\` = no limit.

## Methods

### Public methods

- [`BalanceArgs$new()`](#method-BalanceArgs-initialize)

- [`BalanceArgs$validate()`](#method-BalanceArgs-validate)

Inherited methods

- [`AbstractSerializableSettings$toJson()`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.html#method-toJson)

------------------------------------------------------------------------

### `BalanceArgs$new()`

Construct from named arguments or a JSON string.

#### Usage

    BalanceArgs$new(maxCohortSizeForBalance = 250000L, json = NULL)

#### Arguments

- `maxCohortSizeForBalance`:

  See factory.

- `json`:

  JSON string from \`toJson()\`.

------------------------------------------------------------------------

### `BalanceArgs$validate()`

Validate all fields using checkmate.

#### Usage

    BalanceArgs$validate()
