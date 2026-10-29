# Analysis specification for a single PNU analysis

Bundles all step-specific settings for one run of the PNU pipeline.
Create with \[createPnuAnalysisArgs()\].

## Super class

[`AbstractSerializableSettings`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.md)
-\> `PnuAnalysis`

## Public fields

- `analysisId`:

  Unique integer identifier.

- `description`:

  Human-readable label.

- `pnuCohortArgs`:

  \[PnuCohortArgs\] object; \`NULL\` when \`pnuDataList\` is supplied to
  \[runPnuAnalyses()\].

- `studyPopulationArgs`:

  \[StudyPopulationArgs\] object.

- `tcpsArgs`:

  \[TcpsArgs\] object; \`NULL\` = uniform PS (0.5).

- `matchingArgs`:

  \[MatchingArgs\] object.

- `outcomeModelArgs`:

  \[OutcomeModelArgs\] object.

- `bootstrapArgs`:

  \[BootstrapArgs\] object; \`NULL\` = skip bootstrap.

- `balanceArgs`:

  \[BalanceArgs\] object; \`NULL\` = skip balance.

## Methods

### Public methods

- [`PnuAnalysis$new()`](#method-PnuAnalysis-initialize)

- [`PnuAnalysis$validate()`](#method-PnuAnalysis-validate)

- [`PnuAnalysis$toJson()`](#method-PnuAnalysis-toJson)

------------------------------------------------------------------------

### `PnuAnalysis$new()`

Construct from named arguments or a JSON string.

#### Usage

    PnuAnalysis$new(
      analysisId = 1L,
      description = "",
      pnuCohortArgs = NULL,
      studyPopulationArgs = NULL,
      tcpsArgs = NULL,
      matchingArgs = NULL,
      outcomeModelArgs = NULL,
      bootstrapArgs = NULL,
      balanceArgs = NULL,
      json = NULL
    )

#### Arguments

- `analysisId, description, pnuCohortArgs, studyPopulationArgs, tcpsArgs, matchingArgs, outcomeModelArgs, bootstrapArgs, balanceArgs`:

  See factory.

- `json`:

  JSON string from \`toJson()\` (restores only primitive fields).

------------------------------------------------------------------------

### `PnuAnalysis$validate()`

Validate all fields using checkmate.

#### Usage

    PnuAnalysis$validate()

------------------------------------------------------------------------

### `PnuAnalysis$toJson()`

Serialise to JSON (primitive fields only).

#### Usage

    PnuAnalysis$toJson()

#### Details

Nested settings objects contain Cyclops objects that are not
JSON-serializable; only \`analysisId\` and \`description\` are
round-tripped.
