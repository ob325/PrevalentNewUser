# Settings for TCPS matching

Holds parameters controlling \[matchOnTcps()\]. Create with
\[createMatchingArgs()\].

## Super class

[`AbstractSerializableSettings`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.md)
-\> `MatchingArgs`

## Public fields

- `caliper`:

  Caliper width as a fraction of the SD of the logit-PS (or in logit
  units when \`caliperScale = "logit"\`). \`0\` disables the caliper.

- `caliperScale`:

  Scale on which the caliper is applied.

- `maxRatio`:

  Maximum number of comparators per switcher. \`0\` = variable ratio
  (match all within caliper).

- `allowReverseMatch`:

  If \`TRUE\` and a set has more switchers than comparators, flip labels
  so the minority arm is matched to the majority.

## Methods

### Public methods

- [`MatchingArgs$new()`](#method-MatchingArgs-initialize)

- [`MatchingArgs$validate()`](#method-MatchingArgs-validate)

Inherited methods

- [`AbstractSerializableSettings$toJson()`](https://ob325.github.io/PrevalentNewUser/reference/AbstractSerializableSettings.html#method-toJson)

------------------------------------------------------------------------

### `MatchingArgs$new()`

Construct from named arguments or a JSON string.

#### Usage

    MatchingArgs$new(
      caliper = 0.2,
      caliperScale = "standardized logit",
      maxRatio = 1L,
      allowReverseMatch = FALSE,
      json = NULL
    )

#### Arguments

- `caliper, caliperScale, maxRatio, allowReverseMatch`:

  See factory.

- `json`:

  JSON string from \`toJson()\`.

------------------------------------------------------------------------

### `MatchingArgs$validate()`

Validate all fields using checkmate.

#### Usage

    MatchingArgs$validate()
