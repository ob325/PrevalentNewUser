# Abstract base class for serializable settings objects

Provides JSON round-tripping (\`toJson()\` / \`json\` constructor
argument) and a \`validate()\` hook for all concrete settings classes in
this package. Adapted from CohortMethod's \`R/SettingsObjects.R\`
(Apache 2.0 licence).

## Methods

### Public methods

- [`AbstractSerializableSettings$new()`](#method-AbstractSerializableSettings-initialize)

- [`AbstractSerializableSettings$toJson()`](#method-AbstractSerializableSettings-toJson)

- [`AbstractSerializableSettings$validate()`](#method-AbstractSerializableSettings-validate)

------------------------------------------------------------------------

### `AbstractSerializableSettings$new()`

Populate fields from a JSON string.

#### Usage

    AbstractSerializableSettings$new(json = NULL)

#### Arguments

- `json`:

  A JSON string produced by \`toJson()\`.

------------------------------------------------------------------------

### `AbstractSerializableSettings$toJson()`

Serialise the object to a JSON string.

#### Usage

    AbstractSerializableSettings$toJson()

#### Returns

A single JSON string.

------------------------------------------------------------------------

### `AbstractSerializableSettings$validate()`

Validate the object's fields. Override in subclasses.

#### Usage

    AbstractSerializableSettings$validate()
