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

# ---- SimulationArgs ---------------------------------------------------------

#' Settings for PNU simulation
#'
#' @description
#' Holds all parameters controlling [simulatePnuData()]. Create with
#' [createSimulationArgs()].
#'
#' @keywords internal
SimulationArgs <- R6::R6Class(
  classname = "SimulationArgs",
  inherit = AbstractSerializableSettings,
  cloneable = FALSE,
  public = list(
    #' @field nSwitchers Switchers per exposure set.
    nSwitchers = NULL,
    #' @field nComparatorsPerSet Comparators per exposure set.
    nComparatorsPerSet = NULL,
    #' @field nExposureSets Number of exposure sets.
    nExposureSets = NULL,
    #' @field nCovariates Number of simulated binary covariates.
    nCovariates = NULL,
    #' @field prevalenceBase Baseline covariate prevalence in comparators.
    prevalenceBase = NULL,
    #' @field prevalenceDiff Additional covariate prevalence in switchers.
    prevalenceDiff = NULL,
    #' @field outcomeBaseRate Outcome probability in comparators over the follow-up.
    outcomeBaseRate = NULL,
    #' @field followUpDays Follow-up duration in days.
    followUpDays = NULL,
    #' @field logRr True log hazard ratio (switchers vs. comparators).
    logRr = NULL,
    #' @field seed Integer seed for reproducibility.
    seed = NULL,

    #' @description Construct from named arguments or a JSON string.
    #' @param nSwitchers,nComparatorsPerSet,nExposureSets,nCovariates Population parameters.
    #' @param prevalenceBase,prevalenceDiff Covariate prevalence parameters.
    #' @param outcomeBaseRate,followUpDays,logRr Outcome parameters.
    #' @param seed Integer RNG seed.
    #' @param json JSON string from `toJson()`. When supplied, all other arguments are ignored.
    initialize = function(nSwitchers = 200L,
                          nComparatorsPerSet = 200L,
                          nExposureSets = 3L,
                          nCovariates = 10L,
                          prevalenceBase = 0.2,
                          prevalenceDiff = 0.1,
                          outcomeBaseRate = 0.05,
                          followUpDays = 365L,
                          logRr = 0.0,
                          seed = 1L,
                          json = NULL) {
      self$nSwitchers <- as.integer(nSwitchers)
      self$nComparatorsPerSet <- as.integer(nComparatorsPerSet)
      self$nExposureSets <- as.integer(nExposureSets)
      self$nCovariates <- as.integer(nCovariates)
      self$prevalenceBase <- prevalenceBase
      self$prevalenceDiff <- prevalenceDiff
      self$outcomeBaseRate <- outcomeBaseRate
      self$followUpDays <- as.integer(followUpDays)
      self$logRr <- logRr
      self$seed <- as.integer(seed)
      if (!is.null(json)) {
        super$initialize(json = json)
      }
    },

    #' @description Validate all fields using checkmate.
    validate = function() {
      errorMessages <- checkmate::makeAssertCollection()
      checkmate::assertInt(self$nSwitchers, lower = 1L, add = errorMessages)
      checkmate::assertInt(self$nComparatorsPerSet, lower = 1L, add = errorMessages)
      checkmate::assertInt(self$nExposureSets, lower = 1L, add = errorMessages)
      checkmate::assertInt(self$nCovariates, lower = 0L, add = errorMessages)
      checkmate::assertNumber(self$prevalenceBase, lower = 0.0, upper = 1.0, add = errorMessages)
      checkmate::assertNumber(self$prevalenceDiff, lower = 0.0, upper = 1.0, add = errorMessages)
      checkmate::assertNumber(self$outcomeBaseRate,
        lower = 1e-6, upper = 1 - 1e-6,
        add = errorMessages
      )
      checkmate::assertInt(self$followUpDays, lower = 1L, add = errorMessages)
      checkmate::assertNumber(self$logRr, add = errorMessages)
      checkmate::assertInt(self$seed, add = errorMessages)
      checkmate::reportAssertions(collection = errorMessages)
      invisible(self)
    }
  )
)

# ---- Factory ----------------------------------------------------------------

#' Create simulation arguments
#'
#' @description
#' Specifies the population and outcome parameters for [simulatePnuData()].
#' The simulated `PnuData` has a known treatment effect (`logRr`) and a
#' controllable covariate structure for testing statistical steps without a
#' real database.
#'
#' **Data-generating process**
#'
#' Each exposure set contains `nSwitchers` switchers and `nComparatorsPerSet`
#' comparators. Covariates are binary: P(covariate = 1) = `prevalenceBase` for
#' comparators and `min(1, prevalenceBase + prevalenceDiff)` for switchers
#' (covariates predict treatment but not the outcome, so the crude rate ratio
#' equals `exp(logRr)` asymptotically). Outcome times follow an exponential
#' model with baseline hazard chosen so that comparators have exactly
#' `outcomeBaseRate` probability of an event in `followUpDays` days.
#'
#' @param nSwitchers (`integer(1)`) Number of switchers per exposure set.
#'   Default: `200`.
#' @param nComparatorsPerSet (`integer(1)`) Number of comparators per exposure
#'   set. Default: `200`.
#' @param nExposureSets (`integer(1)`) Number of exposure sets. Set `1` for a
#'   pure ACNU-equivalent simulation. Default: `3`.
#' @param nCovariates (`integer(1)`) Number of simulated binary covariates.
#'   `0` generates no covariates. Default: `10`.
#' @param prevalenceBase (`numeric(1)`) Baseline covariate prevalence in
#'   comparators. Must be in \[0, 1\]. Default: `0.2`.
#' @param prevalenceDiff (`numeric(1)`) Additional covariate prevalence in
#'   switchers (confounding by indication). Must be in \[0, 1\].
#'   Default: `0.1`.
#' @param outcomeBaseRate (`numeric(1)`) Probability of the outcome within
#'   `followUpDays` for a comparator. Must be in (0, 1). Default: `0.05`.
#' @param followUpDays (`integer(1)`) Follow-up period in days. Default: `365`.
#' @param logRr (`numeric(1)`) True log hazard ratio for switchers relative to
#'   comparators. `0` means no treatment effect. Default: `0`.
#' @param seed (`integer(1)`) RNG seed for reproducibility. Default: `1`.
#' @param json (`character(1)`) JSON string from `toJson()`. When supplied,
#'   all other arguments are ignored and values are restored from JSON.
#'
#' @return A `SimulationArgs` R6 object.
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' args <- createSimulationArgs(
#'   nSwitchers = 500L,
#'   nExposureSets = 2L,
#'   logRr = log(2),
#'   seed = 1L
#' )
#'
#' @export
createSimulationArgs <- function(nSwitchers = 200L,
                                 nComparatorsPerSet = 200L,
                                 nExposureSets = 3L,
                                 nCovariates = 10L,
                                 prevalenceBase = 0.2,
                                 prevalenceDiff = 0.1,
                                 outcomeBaseRate = 0.05,
                                 followUpDays = 365L,
                                 logRr = 0.0,
                                 seed = 1L,
                                 json = NULL) {
  if (!is.null(json)) {
    return(SimulationArgs$new(json = json))
  }
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertInt(nSwitchers, lower = 1L, add = errorMessages)
  checkmate::assertInt(nComparatorsPerSet, lower = 1L, add = errorMessages)
  checkmate::assertInt(nExposureSets, lower = 1L, add = errorMessages)
  checkmate::assertInt(nCovariates, lower = 0L, add = errorMessages)
  checkmate::assertNumber(prevalenceBase, lower = 0.0, upper = 1.0, add = errorMessages)
  checkmate::assertNumber(prevalenceDiff, lower = 0.0, upper = 1.0, add = errorMessages)
  checkmate::assertNumber(outcomeBaseRate, lower = 1e-6, upper = 1 - 1e-6, add = errorMessages)
  checkmate::assertInt(followUpDays, lower = 1L, add = errorMessages)
  checkmate::assertNumber(logRr, add = errorMessages)
  checkmate::assertInt(seed, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  SimulationArgs$new(
    nSwitchers = as.integer(nSwitchers),
    nComparatorsPerSet = as.integer(nComparatorsPerSet),
    nExposureSets = as.integer(nExposureSets),
    nCovariates = as.integer(nCovariates),
    prevalenceBase = prevalenceBase,
    prevalenceDiff = prevalenceDiff,
    outcomeBaseRate = outcomeBaseRate,
    followUpDays = as.integer(followUpDays),
    logRr = logRr,
    seed = as.integer(seed)
  )
}

# ---- Simulator --------------------------------------------------------------

#' Simulate a PnuData object with a known treatment effect
#'
#' @description
#' Generates a [PnuData] object whose treatment effect, covariate structure,
#' and outcome rates are determined by `simulationArgs`. All random draws are
#' made under `withr::with_seed()` so the caller's RNG state is restored on
#' exit.
#'
#' **Outcome model** Outcome times follow Exp(lambda) where
#' `lambda = lambda0 * exp(logRr * treatment)` per day, and `lambda0` is
#' chosen so that P(event in `followUpDays` | comparator) = `outcomeBaseRate`.
#'
#' **Covariate model** Each of the `nCovariates` binary covariates is drawn
#' independently. P(X = 1 | comparator) = `prevalenceBase`;
#' P(X = 1 | switcher) = min(1, `prevalenceBase + prevalenceDiff`). Covariates
#' predict treatment assignment only, so the crude outcome rate ratio equals
#' `exp(logRr)` asymptotically.
#'
#' @param simulationArgs A `SimulationArgs` object from [createSimulationArgs()].
#'
#' @return A [PnuData] object. The caller is responsible for closing it with
#'   `Andromeda::close()`. `attr(result, "metaData")$simulationArgs` contains
#'   a JSON snapshot of `simulationArgs`.
#'
#' @seealso [createSimulationArgs()]
#'
#' @examples
#' \dontrun{
#' simArgs <- createSimulationArgs(nSwitchers = 500L, logRr = log(2), seed = 1L)
#' pnuData <- simulatePnuData(simArgs)
#' summary(pnuData)
#' Andromeda::close(pnuData)
#' }
#'
#' @export
simulatePnuData <- function(simulationArgs) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertClass(simulationArgs, "SimulationArgs", add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  withr::with_seed(simulationArgs$seed, {
    nSw <- simulationArgs$nSwitchers
    nCo <- simulationArgs$nComparatorsPerSet
    nSets <- simulationArgs$nExposureSets
    nCov <- simulationArgs$nCovariates
    pBase <- simulationArgs$prevalenceBase
    pDiff <- simulationArgs$prevalenceDiff
    oRate <- simulationArgs$outcomeBaseRate
    fuDays <- simulationArgs$followUpDays
    lrr <- simulationArgs$logRr

    nPerSet <- nSw + nCo
    nTotal <- nSets * nPerSet

    isSwitch <- rep(c(rep(1L, nSw), rep(0L, nCo)), times = nSets)
    setIds <- rep(seq_len(nSets), each = nPerSet)

    indexDate <- as.Date("2000-01-01")

    cohortsTbl <- dplyr::tibble(
      row_id            = seq_len(nTotal),
      person_seq_id     = seq_len(nTotal),
      person_id         = as.character(seq_len(nTotal)),
      cohort_start_date = indexDate,
      cohort_end_date   = indexDate + fuDays,
      treatment         = isSwitch,
      exposure_set_id   = as.integer(setIds)
    )

    exposureSetsTbl <- dplyr::tibble(
      person_seq_id   = seq_len(nTotal),
      exposure_set_id = as.integer(setIds),
      days_on_a       = as.integer(setIds) * 30L
    )

    if (nCov > 0L) {
      prevVec <- pmin(1.0, pBase + isSwitch * pDiff)
      # rbinom fills matrix column-by-column: each column = one covariate
      covMatrix <- matrix(
        stats::rbinom(nTotal * nCov, size = 1L, prob = rep(prevVec, times = nCov)),
        nrow = nTotal, ncol = nCov
      )
      nzIdx <- which(covMatrix == 1L, arr.ind = TRUE)
      if (nrow(nzIdx) > 0L) {
        covariateTbl <- dplyr::tibble(
          row_id          = as.integer(nzIdx[, 1L]),
          covariate_id    = as.numeric(nzIdx[, 2L]),
          covariate_value = 1.0
        )
      } else {
        covariateTbl <- dplyr::tibble(
          row_id = integer(0), covariate_id = numeric(0), covariate_value = numeric(0)
        )
      }
      covRefTbl <- dplyr::tibble(
        covariate_id   = as.numeric(seq_len(nCov)),
        covariate_name = paste0("Simulated covariate ", seq_len(nCov)),
        analysis_id    = 1L,
        concept_id     = as.numeric(seq_len(nCov))
      )
      analysisRefTbl <- dplyr::tibble(
        analysis_id        = 1L,
        analysis_name      = "Simulated binary",
        domain_id          = "Condition",
        start_day          = -365L,
        end_day            = 0L,
        is_binary          = "Y",
        missing_means_zero = "Y"
      )
    } else {
      covariateTbl <- dplyr::tibble(
        row_id = integer(0), covariate_id = numeric(0), covariate_value = numeric(0)
      )
      covRefTbl <- dplyr::tibble(
        covariate_id = numeric(0), covariate_name = character(0),
        analysis_id = integer(0), concept_id = numeric(0)
      )
      analysisRefTbl <- dplyr::tibble(
        analysis_id = integer(0), analysis_name = character(0),
        domain_id = character(0), start_day = integer(0),
        end_day = integer(0), is_binary = character(0),
        missing_means_zero = character(0)
      )
    }

    # Exponential survival: lambda0 chosen so P(event | comparator) = oRate
    lambda0 <- -log(1.0 - oRate) / fuDays
    hazard <- lambda0 * exp(lrr * isSwitch)
    tte <- stats::rexp(nTotal, rate = hazard)
    hasEvent <- tte < fuDays

    if (any(hasEvent)) {
      evIdx <- which(hasEvent)
      outcomeTbl <- dplyr::tibble(
        person_seq_id = as.integer(evIdx),
        outcome_id    = 1L,
        outcome_date  = indexDate + as.integer(floor(tte[evIdx]))
      )
    } else {
      outcomeTbl <- dplyr::tibble(
        person_seq_id = integer(0),
        outcome_id    = integer(0),
        outcome_date  = as.Date(character(0))
      )
    }

    pnuData <- createEmptyPnuData(metaData = list(
      simulationArgs = simulationArgs$toJson()
    ))
    pnuData$cohorts <- cohortsTbl
    pnuData$outcomes <- outcomeTbl
    pnuData$exposureSets <- exposureSetsTbl
    pnuData$covariates <- covariateTbl
    pnuData$covariateRef <- covRefTbl
    pnuData$analysisRef <- analysisRefTbl

    pnuData
  })
}
