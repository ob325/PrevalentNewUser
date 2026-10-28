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

# ---- AbstractSerializableSettings ----------------------------------------

#' Abstract base class for serializable settings objects
#'
#' @description
#' Provides JSON round-tripping (`toJson()` / `json` constructor argument) and
#' a `validate()` hook for all concrete settings classes in this package.
#' Adapted from CohortMethod's `R/SettingsObjects.R` (Apache 2.0 licence).
#'
#' @keywords internal
AbstractSerializableSettings <- R6::R6Class(
  classname = "AbstractSerializableSettings",
  cloneable = FALSE,
  public = list(
    #' @description Populate fields from a JSON string.
    #' @param json A JSON string produced by `toJson()`.
    initialize = function(json = NULL) {
      if (!is.null(json)) {
        fields <- jsonlite::fromJSON(json, simplifyVector = TRUE, simplifyDataFrame = FALSE)
        for (nm in names(fields)) {
          self[[nm]] <- fields[[nm]]
        }
      }
    },

    #' @description Serialise the object to a JSON string.
    #' @return A single JSON string.
    toJson = function() {
      env <- self$.__enclos_env__$self
      nms <- setdiff(ls(env, sorted = TRUE), ".__enclos_env__")
      flds <- Filter(function(nm) !is.function(env[[nm]]), nms)
      result <- stats::setNames(lapply(flds, function(nm) env[[nm]]), flds)
      jsonlite::toJSON(result, pretty = TRUE, auto_unbox = TRUE, null = "null")
    },

    #' @description Validate the object's fields. Override in subclasses.
    validate = function() invisible(self)
  )
)

# ---- PnuCohortArgs -------------------------------------------------------

#' Settings for identifying the PNU cohorts
#'
#' @description
#' Specifies which cohorts represent treatment A (reference), treatment B
#' (the new treatment / switcher index events), and the outcome, together with
#' covariate-filter and study-size options. Create with [createPnuCohortArgs()].
#'
#' @keywords internal
PnuCohortArgs <- R6::R6Class(
  classname = "PnuCohortArgs",
  inherit = AbstractSerializableSettings,
  cloneable = FALSE,
  public = list(
    #' @field targetCohortId Cohort ID for treatment A (reference treatment).
    targetCohortId = NULL,
    #' @field comparatorCohortId Cohort ID for treatment B (switcher events).
    comparatorCohortId = NULL,
    #' @field outcomeCohortId Cohort ID for the outcome.
    outcomeCohortId = NULL,
    #' @field excludedCovariateConceptIds Concept IDs excluded from covariate construction.
    excludedCovariateConceptIds = integer(0),
    #' @field includedCovariateConceptIds Concept IDs to include (empty = all).
    includedCovariateConceptIds = integer(0),
    #' @field washoutPeriod Days of observation required before cohort start.
    washoutPeriod = 365L,
    #' @field maxCohortSize Maximum cohort size; 0 = no limit.
    maxCohortSize = 0L,

    #' @description Construct from named arguments or a JSON string.
    #' @param targetCohortId,comparatorCohortId,outcomeCohortId Cohort IDs.
    #' @param excludedCovariateConceptIds,includedCovariateConceptIds Integer vectors of concept IDs.
    #' @param washoutPeriod Days of prior observation required.
    #' @param maxCohortSize Maximum number of subjects per cohort (0 = no limit).
    #' @param json JSON string from `toJson()`. When supplied all other arguments are ignored.
    initialize = function(targetCohortId = NULL,
                          comparatorCohortId = NULL,
                          outcomeCohortId = NULL,
                          excludedCovariateConceptIds = integer(0),
                          includedCovariateConceptIds = integer(0),
                          washoutPeriod = 365L,
                          maxCohortSize = 0L,
                          json = NULL) {
      self$targetCohortId <- targetCohortId
      self$comparatorCohortId <- comparatorCohortId
      self$outcomeCohortId <- outcomeCohortId
      self$excludedCovariateConceptIds <- excludedCovariateConceptIds
      self$includedCovariateConceptIds <- includedCovariateConceptIds
      self$washoutPeriod <- washoutPeriod
      self$maxCohortSize <- maxCohortSize
      if (!is.null(json)) {
        super$initialize(json = json)
      }
    },

    #' @description Validate all fields using checkmate.
    validate = function() {
      errorMessages <- checkmate::makeAssertCollection()
      checkmate::assertInt(self$targetCohortId, lower = 1, add = errorMessages)
      checkmate::assertInt(self$comparatorCohortId, lower = 1, add = errorMessages)
      checkmate::assertInt(self$outcomeCohortId, lower = 1, add = errorMessages)
      checkmate::assertIntegerish(
        self$excludedCovariateConceptIds,
        lower = 0, null.ok = FALSE, add = errorMessages
      )
      checkmate::assertIntegerish(
        self$includedCovariateConceptIds,
        lower = 0, null.ok = FALSE, add = errorMessages
      )
      checkmate::assertInt(self$washoutPeriod, lower = 0, add = errorMessages)
      checkmate::assertInt(self$maxCohortSize, lower = 0, add = errorMessages)
      checkmate::reportAssertions(collection = errorMessages)
      invisible(self)
    }
  )
)

# ---- Exported factory ----------------------------------------------------

#' Create PNU cohort arguments
#'
#' @description
#' Specifies which cohorts play the roles of reference treatment (A),
#' new treatment / switcher events (B), and outcome, along with covariate
#' filters and population-size limits.
#'
#' @param targetCohortId (`integer(1)`) Cohort ID for treatment A (reference
#'   treatment; patients must be on this treatment before the index date).
#' @param comparatorCohortId (`integer(1)`) Cohort ID for treatment B (the
#'   new treatment; switcher index events are the start dates in this cohort).
#' @param outcomeCohortId (`integer(1)`) Cohort ID for the outcome of interest.
#' @param excludedCovariateConceptIds (`integer`) Concept IDs to exclude when
#'   constructing covariates (e.g. drugs directly on the causal pathway).
#'   Default: `integer(0)` (none excluded).
#' @param includedCovariateConceptIds (`integer`) Concept IDs to include when
#'   constructing covariates. An empty vector means all concepts are included.
#'   Default: `integer(0)`.
#' @param washoutPeriod (`integer(1)`) Minimum days of continuous observation
#'   required before a subject's cohort start date. Default: `365`.
#' @param maxCohortSize (`integer(1)`) Maximum number of subjects in each
#'   cohort. `0` means no limit. Default: `0`.
#'
#' @return A `PnuCohortArgs` R6 object.
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468.
#' \doi{10.1002/pds.4117}
#'
#' @examples
#' args <- createPnuCohortArgs(
#'   targetCohortId = 1,
#'   comparatorCohortId = 2,
#'   outcomeCohortId = 3
#' )
#'
#' @export
createPnuCohortArgs <- function(targetCohortId,
                                comparatorCohortId,
                                outcomeCohortId,
                                excludedCovariateConceptIds = integer(0),
                                includedCovariateConceptIds = integer(0),
                                washoutPeriod = 365,
                                maxCohortSize = 0) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertInt(targetCohortId, lower = 1, add = errorMessages)
  checkmate::assertInt(comparatorCohortId, lower = 1, add = errorMessages)
  checkmate::assertInt(outcomeCohortId, lower = 1, add = errorMessages)
  checkmate::assertIntegerish(excludedCovariateConceptIds, lower = 0, null.ok = FALSE, add = errorMessages)
  checkmate::assertIntegerish(includedCovariateConceptIds, lower = 0, null.ok = FALSE, add = errorMessages)
  checkmate::assertInt(washoutPeriod, lower = 0, add = errorMessages)
  checkmate::assertInt(maxCohortSize, lower = 0, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  PnuCohortArgs$new(
    targetCohortId = as.integer(targetCohortId),
    comparatorCohortId = as.integer(comparatorCohortId),
    outcomeCohortId = as.integer(outcomeCohortId),
    excludedCovariateConceptIds = as.integer(excludedCovariateConceptIds),
    includedCovariateConceptIds = as.integer(includedCovariateConceptIds),
    washoutPeriod = as.integer(washoutPeriod),
    maxCohortSize = as.integer(maxCohortSize)
  )
}
