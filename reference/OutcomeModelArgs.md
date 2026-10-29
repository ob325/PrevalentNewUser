# Settings for outcome model fitting

Holds parameters controlling \[fitOutcomeModel()\]. Create with
\[createOutcomeModelArgs()\].

The \`prior\` and \`control\` fields are Cyclops objects and are omitted
from JSON serialization (same pattern as \[TcpsArgs\]).

## Super class

[`AbstractSerializableSettings`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.md)
-\> `OutcomeModelArgs`

## Public fields

- `modelType`:

  Outcome model type: \`"cox"\`, \`"logistic"\`, or \`"poisson"\`.

- `stratified`:

  Stratify on \`stratumId\` (matched sets)?

- `useCovariates`:

  Include covariates from \`pnuData\` in the outcome model?

- `prior`:

  Cyclops prior (\`cyclopsPrior\`), or \`NULL\` for default.

- `control`:

  Cyclops control (\`cyclopsControl\`), or \`NULL\` for default.

## Methods

### Public methods

- [`OutcomeModelArgs$new()`](#method-OutcomeModelArgs-initialize)

- [`OutcomeModelArgs$toJson()`](#method-OutcomeModelArgs-toJson)

- [`OutcomeModelArgs$validate()`](#method-OutcomeModelArgs-validate)

------------------------------------------------------------------------

### `OutcomeModelArgs$new()`

Construct from named arguments or a JSON string.

#### Usage

    OutcomeModelArgs$new(
      modelType = "cox",
      stratified = TRUE,
      useCovariates = FALSE,
      prior = NULL,
      control = NULL,
      json = NULL
    )

#### Arguments

- `modelType, stratified, useCovariates, prior, control`:

  See factory.

- `json`:

  JSON string from \`toJson()\`. \`prior\` and \`control\` are not
  restored; supply them again via \[createOutcomeModelArgs()\].

------------------------------------------------------------------------

### `OutcomeModelArgs$toJson()`

Serialise to JSON (prior and control fields are omitted).

#### Usage

    OutcomeModelArgs$toJson()

------------------------------------------------------------------------

### `OutcomeModelArgs$validate()`

Validate all fields using checkmate.

#### Usage

    OutcomeModelArgs$validate()
