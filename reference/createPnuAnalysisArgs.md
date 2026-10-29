# Create a PNU analysis specification

Bundles all step-specific settings for one run of the PNU pipeline. Pass
a list of these objects to \[runPnuAnalyses()\].

## Usage

``` r
createPnuAnalysisArgs(
  analysisId = 1L,
  description = "",
  pnuCohortArgs = NULL,
  studyPopulationArgs,
  tcpsArgs = NULL,
  matchingArgs,
  outcomeModelArgs,
  bootstrapArgs = NULL,
  balanceArgs = NULL
)
```

## Arguments

- analysisId:

  (\`integer(1)\`) Unique analysis identifier. Default: \`1\`.

- description:

  (\`character(1)\`) Human-readable label. Default: \`""\`.

- pnuCohortArgs:

  A \[PnuCohortArgs\] object specifying cohort IDs. Required when
  \[runPnuAnalyses()\] loads data from a database; optional (pass
  \`NULL\`) when \`pnuDataList\` is supplied.

- studyPopulationArgs:

  A \[StudyPopulationArgs\] object.

- tcpsArgs:

  A \[TcpsArgs\] object. Pass \`NULL\` (default) to skip TCPS fitting
  and assign propensity score \`0.5\` uniformly — useful for testing
  set-0 equivalence with CohortMethod.

- matchingArgs:

  A \[MatchingArgs\] object.

- outcomeModelArgs:

  An \[OutcomeModelArgs\] object.

- bootstrapArgs:

  A \[BootstrapArgs\] object, or \`NULL\` (default) to skip
  bootstrapping and use Wald-type CIs from the outcome model.

- balanceArgs:

  A \[BalanceArgs\] object, or \`NULL\` (default) to skip covariate
  balance computation.

## Value

A \`PnuAnalysis\` R6 object.

## See also

\[runPnuAnalyses()\]

## Examples

``` r
analysis <- createPnuAnalysisArgs(
  analysisId          = 1L,
  description         = "Primary analysis",
  studyPopulationArgs = createStudyPopulationArgs(outcomeId = 1L),
  matchingArgs        = createMatchingArgs(),
  outcomeModelArgs    = createOutcomeModelArgs()
)
```
