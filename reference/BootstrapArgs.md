# Settings for bootstrap confidence intervals

Holds parameters controlling \[bootstrapCi()\]. Create with
\[createBootstrapArgs()\].

## Super class

[`AbstractSerializableSettings`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.md)
-\> `BootstrapArgs`

## Public fields

- `numberOfReplications`:

  Number of bootstrap resamples.

- `seed`:

  RNG seed for reproducible resampling.

- `cores`:

  Number of parallel workers (\`1\` = sequential).

## Methods

### Public methods

- [`BootstrapArgs$new()`](#method-BootstrapArgs-initialize)

- [`BootstrapArgs$validate()`](#method-BootstrapArgs-validate)

Inherited methods

- [`AbstractSerializableSettings$toJson()`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.html#method-toJson)

------------------------------------------------------------------------

### `BootstrapArgs$new()`

Construct from named arguments or a JSON string.

#### Usage

    BootstrapArgs$new(
      numberOfReplications = 1000L,
      seed = 1L,
      cores = 1L,
      json = NULL
    )

#### Arguments

- `numberOfReplications, seed, cores`:

  See factory.

- `json`:

  JSON string from \`toJson()\`.

------------------------------------------------------------------------

### `BootstrapArgs$validate()`

Validate all fields using checkmate.

#### Usage

    BootstrapArgs$validate()
