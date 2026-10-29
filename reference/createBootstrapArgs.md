# Create bootstrap arguments

Specifies parameters for \[bootstrapCi()\].

## Usage

``` r
createBootstrapArgs(numberOfReplications = 1000L, seed = 1L, cores = 1L)
```

## Arguments

- numberOfReplications:

  (\`integer(1)\`) Number of bootstrap resamples. Default: \`1000\`.

- seed:

  (\`integer(1)\`) RNG seed for reproducible resampling. Default: \`1\`.

- cores:

  (\`integer(1)\`) Number of parallel workers. \`1\` (default) runs
  sequentially. Values \> 1 use \`parallel::mclapply\` (Unix/macOS only;
  falls back to sequential on Windows).

## Value

A \`BootstrapArgs\` R6 object.

## See also

\[bootstrapCi()\]

## Examples

``` r
bootstrapArgs <- createBootstrapArgs()
bootstrapArgs <- createBootstrapArgs(numberOfReplications = 200L, seed = 42L)
```
