# Copyright 2026 Observational Health Data Sciences and Informatics
#
# This file is part of PrevalentNewUser
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ---- S4 class definition -------------------------------------------------

#' @importFrom methods setClass setMethod is new
NULL

#' An S4 class for prevalent new-user study data
#'
#' @description
#' `PnuData` extends `CovariateData` (from FeatureExtraction) and is the
#' central data container passed between all analytical steps. Like
#' `CovariateData`, it is backed by an Andromeda (DuckDB) database and holds
#' its tables as database tables accessed via the `$` operator, not as S4
#' slots.
#'
#' Core tables (in addition to the covariates / covariateRef / analysisRef
#' tables inherited from `CovariateData`):
#'
#' | Table | Key columns |
#' |---|---|
#' | `cohorts` | `row_id`, `person_seq_id`, `person_id`, `cohort_start_date`, `cohort_end_date`, `treatment`, `exposure_set_id` |
#' | `outcomes` | `person_seq_id`, `outcome_id`, `outcome_date` |
#' | `exposureSets` | `person_seq_id`, `exposure_set_id`, `days_on_a` |
#'
#' `treatment` = 1 for switchers (target), 0 for comparators.
#' `exposure_set_id` = 0 means no prior treatment A (equivalent to ACNU).
#'
#' Create with [createEmptyPnuData()] (internal) or [getDbPnuData()] (Step 3.1).
#'
#' @seealso [isPnuData()], [getDbPnuData()], [savePnuData()], [loadPnuData()]
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @export
setClass("PnuData", contains = "CovariateData")

# ---- Constructor (internal) ----------------------------------------------

#' Create an empty PnuData object
#'
#' @description
#' Returns an Andromeda-backed `PnuData` object with all tables present but
#' zero rows. Used for testing and as the base structure that `getDbPnuData()`
#' populates.
#'
#' @param metaData A named list of metadata to attach (passed to
#'   `attr(x, "metaData")`).
#'
#' @return A `PnuData` object.
#'
#' @keywords internal
createEmptyPnuData <- function(metaData = list()) {
  pnuData <- Andromeda::andromeda(
    cohorts = dplyr::tibble(
      row_id = integer(0),
      person_seq_id = integer(0),
      person_id = character(0),
      cohort_start_date = as.Date(character(0)),
      cohort_end_date = as.Date(character(0)),
      treatment = integer(0),
      exposure_set_id = integer(0)
    ),
    outcomes = dplyr::tibble(
      person_seq_id = integer(0),
      outcome_id = integer(0),
      outcome_date = as.Date(character(0))
    ),
    exposureSets = dplyr::tibble(
      person_seq_id = integer(0),
      exposure_set_id = integer(0),
      days_on_a = integer(0)
    ),
    covariates = dplyr::tibble(
      row_id = integer(0),
      covariate_id = numeric(0),
      covariate_value = numeric(0)
    ),
    covariateRef = dplyr::tibble(
      covariate_id = numeric(0),
      covariate_name = character(0),
      analysis_id = integer(0),
      concept_id = numeric(0)
    ),
    analysisRef = dplyr::tibble(
      analysis_id = integer(0),
      analysis_name = character(0),
      domain_id = character(0),
      start_day = integer(0),
      end_day = integer(0),
      is_binary = character(0),
      missing_means_zero = character(0)
    ),
    studyPopulation = dplyr::tibble(
      row_id = integer(0),
      person_seq_id = integer(0),
      person_id = character(0),
      cohort_start_date = as.Date(character(0)),
      cohort_end_date = as.Date(character(0)),
      treatment = integer(0),
      exposure_set_id = integer(0),
      survival_time = integer(0),
      outcome_count = integer(0),
      days_to_event = integer(0)
    )
  )
  attr(pnuData, "metaData") <- metaData
  class(pnuData) <- "PnuData"
  pnuData
}

# ---- Predicate -----------------------------------------------------------

#' Test whether an object is a PnuData instance
#'
#' @param x Object to test.
#'
#' @return `TRUE` if `x` inherits from `PnuData`, `FALSE` otherwise.
#'
#' @examples
#' \dontrun{
#' pnuData <- getDbPnuData(...)
#' isPnuData(pnuData) # TRUE
#' isPnuData(list()) # FALSE
#' }
#'
#' @export
isPnuData <- function(x) {
  inherits(x, "PnuData")
}

# ---- show (print) --------------------------------------------------------

#' @describeIn PnuData Print a concise summary of a PnuData object.
#' @param object A `PnuData` object.
#' @export
setMethod("show", "PnuData", function(object) {
  cli::cat_line(pillar::style_subtle("# PnuData object"))
  cli::cat_line("")

  metaData <- attr(object, "metaData")

  if (!is.null(metaData$databaseId)) {
    cli::cat_line(paste("Database ID:      ", metaData$databaseId))
  }
  if (!is.null(metaData$targetCohortId)) {
    cli::cat_line(paste("Target cohort ID: ", metaData$targetCohortId))
    cli::cat_line(paste("Comparator ID:    ", metaData$comparatorCohortId))
    cli::cat_line(paste("Outcome ID:       ", metaData$outcomeCohortId))
  }

  if (!is.null(object$cohorts)) {
    nTotal <- object$cohorts |>
      dplyr::count() |>
      dplyr::pull()
    nTarget <- object$cohorts |>
      dplyr::filter(.data$treatment == 1L) |>
      dplyr::count() |>
      dplyr::pull()
    nSets <- object$exposureSets |>
      dplyr::distinct(.data$exposure_set_id) |>
      dplyr::count() |>
      dplyr::pull()
    cli::cat_line("")
    cli::cat_line(paste("Switchers (target):  ", nTarget))
    cli::cat_line(paste("Comparators:         ", nTotal - nTarget))
    cli::cat_line(paste("Exposure sets:       ", nSets))
  }

  cli::cat_line("")
  cli::cat_line(pillar::style_subtle("Inherits from Andromeda:"))
  class(object) <- "Andromeda"
  methods::show(object)
})

# ---- summary -------------------------------------------------------------

#' Summarise a PnuData object
#'
#' @param object A `PnuData` object.
#' @param ... Ignored.
#'
#' @return A list of class `summary.PnuData` with components:
#'   `metaData`, `switcherCount`, `comparatorCount`, `exposureSetCount`,
#'   `outcomeCount`, `covariateCount`, `covariateValueCount`.
#'
#' @export
setMethod("summary", "PnuData", function(object, ...) {
  switcherCount <- object$cohorts |>
    dplyr::filter(.data$treatment == 1L) |>
    dplyr::count() |>
    dplyr::pull()

  comparatorCount <- object$cohorts |>
    dplyr::filter(.data$treatment == 0L) |>
    dplyr::count() |>
    dplyr::pull()

  exposureSetCount <- object$exposureSets |>
    dplyr::distinct(.data$exposure_set_id) |>
    dplyr::count() |>
    dplyr::pull()

  outcomeCount <- object$outcomes |>
    dplyr::count() |>
    dplyr::pull()

  covariateCount <- object$covariateRef |>
    dplyr::count() |>
    dplyr::pull()

  covariateValueCount <- object$covariates |>
    dplyr::count() |>
    dplyr::pull()

  result <- list(
    metaData = attr(object, "metaData"),
    switcherCount = switcherCount,
    comparatorCount = comparatorCount,
    exposureSetCount = exposureSetCount,
    outcomeCount = outcomeCount,
    covariateCount = covariateCount,
    covariateValueCount = covariateValueCount
  )
  class(result) <- "summary.PnuData"
  result
})

#' @export
print.summary.PnuData <- function(x, ...) {
  cli::cat_line(pillar::style_subtle("# Summary of PnuData object"))
  cli::cat_line("")
  cli::cat_line(paste("Switchers (target): ", x$switcherCount))
  cli::cat_line(paste("Comparators:        ", x$comparatorCount))
  cli::cat_line(paste("Exposure sets:      ", x$exposureSetCount))
  cli::cat_line(paste("Outcome records:    ", x$outcomeCount))
  cli::cat_line(paste("Covariates:         ", x$covariateCount))
  cli::cat_line(paste("Covariate values:   ", x$covariateValueCount))
  invisible(x)
}
