# Create an empty PnuData object

Returns an Andromeda-backed \`PnuData\` object with all tables present
but zero rows. Used for testing and as the base structure that
\`getDbPnuData()\` populates.

## Usage

``` r
createEmptyPnuData(metaData = list())
```

## Arguments

- metaData:

  A named list of metadata to attach (passed to \`attr(x,
  "metaData")\`).

## Value

A \`PnuData\` object.
