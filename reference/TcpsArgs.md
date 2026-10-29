# Settings for TCPS fitting

Holds parameters controlling \[fitTcps()\]. Create with
\[createTcpsArgs()\].

The \`prior\` and \`control\` fields are Cyclops objects and cannot be
round-tripped through JSON. If \`toJson()\` is called on a \`TcpsArgs\`
object, those fields are omitted and must be re-supplied when recreating
the object.

## Super class

[`AbstractSerializableSettings`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.md)
-\> `TcpsArgs`

## Public fields

- `prior`:

  Cyclops prior specification (\`cyclopsPrior\`), or \`NULL\` for
  default.

- `control`:

  Cyclops control specification (\`cyclopsControl\`), or \`NULL\` for
  default.

- `excludedCovariateConceptIds`:

  Concept IDs to exclude from covariate construction.

- `includedCovariateConceptIds`:

  Concept IDs to include (empty = all).

- `maxCohortSizeForFitting`:

  Maximum persons per arm for fitting; 0 = no limit.

- `seed`:

  RNG seed for downsampling reproducibility.

## Methods

### Public methods

- [`TcpsArgs$new()`](#method-TcpsArgs-initialize)

- [`TcpsArgs$toJson()`](#method-TcpsArgs-toJson)

- [`TcpsArgs$validate()`](#method-TcpsArgs-validate)

------------------------------------------------------------------------

### `TcpsArgs$new()`

Construct from named arguments or a JSON string.

#### Usage

    TcpsArgs$new(
      prior = NULL,
      control = NULL,
      excludedCovariateConceptIds = integer(0),
      includedCovariateConceptIds = integer(0),
      maxCohortSizeForFitting = 250000L,
      seed = 1L,
      json = NULL
    )

#### Arguments

- `prior, control, excludedCovariateConceptIds, includedCovariateConceptIds`:

  See factory.

- `maxCohortSizeForFitting, seed`:

  See factory.

- `json`:

  JSON string from \`toJson()\`. \`prior\` and \`control\` are not
  restored from JSON; supply them again via \[createTcpsArgs()\].

------------------------------------------------------------------------

### `TcpsArgs$toJson()`

Serialise to JSON (prior and control fields are omitted).

#### Usage

    TcpsArgs$toJson()

------------------------------------------------------------------------

### `TcpsArgs$validate()`

Validate all fields using checkmate.

#### Usage

    TcpsArgs$validate()
