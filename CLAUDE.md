# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this package does

**PrevalentNewUser** is an OHDSI HADES R package that implements the prevalent new-user (PNU) cohort design (Suissa, Moodie & Dell'Aniello, *Pharmacoepidemiol Drug Saf* 2017;26(4):459–468) for data in the OMOP Common Data Model.

It sits alongside **CohortMethod**, which remains the package for active-comparator new-user (ACNU) designs. PrevalentNewUser does **not** depend on CohortMethod at runtime. CohortMethod is used only in tests, as a reference implementation (see "Set 0 equivalence" below).

The package reuses lower-level HADES libraries: DatabaseConnector, SqlRender, FeatureExtraction, Andromeda, Cyclops, EmpiricalCalibration, ParallelLogger and ResultModelManager.

## Terms used throughout

| Term | Meaning |
| --- | --- |
| Reference treatment (A) | The treatment patients start on, given as a cohort (e.g. GLP-1 RA exposure eras). |
| New treatment (B) | The treatment some patients switch to or add, given as a cohort of start dates (e.g. first bariatric procedure). |
| Switcher (target) | A person who starts B. Their B start date is their index date. |
| Exposure set | A group of switchers who had the same history of A when they started B (same time on A, or same number of A fills). Set 0 = no prior A. |
| Comparator | A person still on A, who has not started B, at the same point in A therapy as a switcher. Indexed on that day. A person can be a comparator in several sets. |
| Time-conditional propensity score (TCPS) | P(switch to B) given covariates, fitted by conditional logistic regression stratified by exposure set. |
| Matched set | One switcher plus its matched comparators, within one exposure set. The stratum for the outcome model. |
| Set 0 equivalence | A run restricted to exposure set 0 is an ACNU analysis and should reproduce CohortMethod with equivalent settings. |

## How we work: one step at a time

The implementation plan is in `extras/ImplementationPlan.md`. It is divided into phases and numbered steps. **Work on exactly one step per session turn, then stop.**

For each step:

1. Read the step in `extras/ImplementationPlan.md`, and any earlier steps it depends on. If anything in the step is ambiguous, or conflicts with the code as it now stands, **ask before writing code**.
2. Implement only what the step describes. Don't refactor unrelated code, add features from later steps, or "tidy up" files outside the step's file list. If you think the plan is wrong, say so in the step report instead of silently deviating.
3. Write or update the tests listed in the step. Run them with `devtools::test(filter = "<file>")`. At the end of each phase, also run `devtools::check()`.
4. Run `styler::style_file()` on every R file you touched, and `devtools::document()` if roxygen changed.
5. In `extras/ImplementationPlan.md`, tick the step's checkbox and add one line to the **Decisions log** for any choice the step left open.
6. **Never commit, stage, push, or create branches.** Leave all changes in the working tree. The developer reviews and commits.
7. Stop and post a **step report** (format below). Don't start the next step until the developer explicitly says to continue.

Some steps are marked **DECISION POINT**. At those steps, before writing code, present the options listed in the plan (plus any you think are missing), give a recommendation, and wait for an answer.

### Step report format

```
## Step <n.m>: <title>

**What changed**
- <file>: <one line on what and why>

**How it works**
<3–8 sentences a reviewer can read before opening the diff. Explain the key logic, especially any SQL.>

**Side effects introduced**
<Functions in this step that touch a database, disk, Andromeda, global options or the RNG, or "None".>

**How to verify**
- <exact commands, e.g. devtools::test(filter = "exposureSets")>
- <what to look at in the output>

**Test results**
<pass/fail counts; paste any failure>

**Open questions / deviations from the plan**
<or "None">
```

## Repository layout

```
R/                     R code (one topic per file, see below)
inst/sql/              OHDSI SQL templates, rendered with SqlRender
inst/csv/              Results data model specification
tests/testthat/        testthat tests; Eunomia for database tests
extras/                Not built into the package: plan, maintenance and simulation scripts
vignettes/             User documentation
```

Planned R files, named after CohortMethod's equivalents where one exists: `PrevalentNewUser.R` (package doc and imports), `SettingsObjects.R`, `ExposureSets.R`, `DataLoadingSaving.R`, `PnuData.R`, `Simulation.R`, `StudyPopulation.R`, `Tcps.R`, `Matching.R`, `Balance.R`, `OutcomeModels.R`, `Bootstrap.R`, `RunAnalyses.R`, `Calibration.R`, `Export.R`, `ResultsDataModel.R`, `HelperFunctions.R`.

## Where side effects happen

Keep database, file and Andromeda I/O in clearly identifiable functions so a reader can tell at a glance where the outside world is touched:

- Functions that **read from or write to a database** take a `connection` or `connectionDetails` argument and are named `getDb*()`, `create*Tables()`, `drop*Tables()` or `upload*()`.
- Functions that **read or write files** are named `save*()`, `load*()`, `export*()` or `write*()`, and take a file or folder argument.
- `run*()` functions orchestrate and may do all of the above.
- Everything else (settings, `createStudyPopulation()`, matching, balance, model fitting on in-memory or Andromeda data) should not write to disk, the database, or global state. If such a function must modify an Andromeda object in place (Andromeda is a reference object), say so in its roxygen `@details` and in the step report.
- Any function that uses random numbers takes a `seed` (in its settings object) and restores the caller's RNG state on exit, using `withr::with_seed()`.

## HADES R style

Follow CohortMethod as the reference for style. When unsure, open the corresponding CohortMethod file and do what it does.

- Every R file starts with the Apache 2.0 license header used in CohortMethod, with "This file is part of PrevalentNewUser".
- `camelCase` for functions, arguments and variables. `PascalCase` for R6 and S4 class names. Internal helpers start with `.` only when CohortMethod would do so; otherwise they're simply unexported.
- Assignment with `<-`. Two-space indentation. Native pipe `|>`.
- Format with `styler::style_pkg()` (tidyverse style), as in CohortMethod's `extras/PackageMaintenance.R`.
- Package-level imports live in `R/PrevalentNewUser.R` as roxygen tags, following CohortMethod: `@import DatabaseConnector`, `@import Andromeda`, `@import dplyr`, `@import R6`, `@importFrom rlang .data`, and `@importFrom` for stats and utils functions. Call every other package with `pkg::fun()`.
- Use `.data$column` inside dplyr verbs to avoid global-variable notes.
- **Argument checking:** every exported function starts with a `checkmate` assertion collection, exactly as CohortMethod does:

  ```r
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertInt(binWidthDays, lower = 1, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)
  ```

- **Messages and logging:** `message()` for user-facing progress, `ParallelLogger::logInfo()`, `logDebug()` and `logWarn()` inside `run*()` pipelines, as CohortMethod does. Don't use `print()` or `cat()` except in `print` methods.
- **Settings objects** are R6 classes built on an `AbstractSerializableSettings` base class, copied and adapted from CohortMethod's `R/SettingsObjects.R` (same organization and license). Each settings object has an exported `create*Args()` function, a `validate()` method using checkmate, and JSON round-tripping via `toJson()` and a `json` constructor argument.
- **Documentation:** roxygen2 with markdown. Every exported function has `@param` for each argument, `@return`, `@details` where behaviour isn't obvious, and an `@examples` block (wrapped in `\dontrun{}` if it needs a database). Cite papers in `@references`.
- **Data objects:** `PnuData` is an S4 class that `contains = "CovariateData"`, following `CohortMethodData`.
- No `library()` or `require()` calls in `R/`. No `T`/`F`; use `TRUE`/`FALSE`. No `setwd()`, `options()` changes without restoring them, or writes outside the user-supplied folders.

## HADES SQL style

Follow CohortMethod's `inst/sql/*.sql` as the reference.

- Write OHDSI SQL (SQL Server flavour), translated with `SqlRender::loadRenderTranslateSql(sqlFilename, packageName = "PrevalentNewUser", dbms = connection@dbms, tempEmulationSchema = tempEmulationSchema, ...)`.
- Every file starts with the license header in a `/* ... */` block, then `{DEFAULT @param = value}` lines for every parameter.
- Parameters are `@snake_case`; table and column names are `snake_case`. SQL keywords in UPPER CASE.
- Temp tables use `#` (e.g. `#pnu_cohorts`), are dropped with `DROP TABLE IF EXISTS` before creation, and are cleaned up by a `Drop*.sql` file called from `on.exit()` in the R function that created them.
- Use `{@condition} ? {...} : {...}` for optional logic rather than building SQL strings in R.
- Use `DATEADD()` and `DATEDIFF()` for dates. No dialect-specific functions. Random ordering uses `ORDER BY NEWID()`, as CohortMethod's `SampleCohorts.sql` does.
- Store `person_id` as `VARCHAR` when bringing it into R, and generate an integer `person_seq_id`, as CohortMethod's `GetCohorts.sql` does.
- Every new SQL file must be tested on Eunomia (SQLite). Where feasible, also check that it translates without error for `sql server`, `postgresql`, `redshift`, `oracle`, `snowflake`, `spark` and `bigquery` using `SqlRender::translate()` in a test.

## Testing

- testthat (edition 3). Database tests use Eunomia, set up in `tests/testthat/setup.R` as in CohortMethod, and are skipped when Eunomia isn't installed.
- Exposure-set logic is tested against a pure R reference implementation (`computeExposureSetsInR()`, built in Phase 1) on small hand-built fixtures inserted into Eunomia with `DatabaseConnector::insertTable()`. The fixture from the pitch (six patients, switchers at months 4 and 9) must be one of them.
- Statistical steps are tested on data from `simulatePnuData()`, where the true effect is known.
- Tests that take more than a few seconds go in `extras/` scripts, not in `tests/`.

## Things not to do

- Don't add a runtime dependency on CohortMethod.
- Don't copy large blocks of CohortMethod code without saying so in the step report. Small, attributed adaptations (like the settings base class) are fine; the license is the same.
- Don't change the public API defined in the plan without raising it as an open question.
- Don't commit.
