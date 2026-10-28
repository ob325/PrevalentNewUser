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

# ---- TcpsArgs ---------------------------------------------------------------

#' Settings for TCPS fitting
#'
#' @description
#' Holds parameters controlling [fitTcps()]. Create with [createTcpsArgs()].
#'
#' The `prior` and `control` fields are Cyclops objects and cannot be
#' round-tripped through JSON. If `toJson()` is called on a `TcpsArgs` object,
#' those fields are omitted and must be re-supplied when recreating the object.
#'
#' @keywords internal
TcpsArgs <- R6::R6Class(
  classname = "TcpsArgs",
  inherit = AbstractSerializableSettings,
  cloneable = FALSE,
  public = list(
    #' @field prior Cyclops prior specification (`cyclopsPrior`), or `NULL` for default.
    prior = NULL,
    #' @field control Cyclops control specification (`cyclopsControl`), or `NULL` for default.
    control = NULL,
    #' @field excludedCovariateConceptIds Concept IDs to exclude from covariate construction.
    excludedCovariateConceptIds = NULL,
    #' @field includedCovariateConceptIds Concept IDs to include (empty = all).
    includedCovariateConceptIds = NULL,
    #' @field maxCohortSizeForFitting Maximum persons per arm for fitting; 0 = no limit.
    maxCohortSizeForFitting = NULL,
    #' @field seed RNG seed for downsampling reproducibility.
    seed = NULL,

    #' @description Construct from named arguments or a JSON string.
    #' @param prior,control,excludedCovariateConceptIds,includedCovariateConceptIds See factory.
    #' @param maxCohortSizeForFitting,seed See factory.
    #' @param json JSON string from `toJson()`. `prior` and `control` are not
    #'   restored from JSON; supply them again via [createTcpsArgs()].
    initialize = function(prior = NULL,
                          control = NULL,
                          excludedCovariateConceptIds = integer(0),
                          includedCovariateConceptIds = integer(0),
                          maxCohortSizeForFitting = 250000L,
                          seed = 1L,
                          json = NULL) {
      self$prior <- prior
      self$control <- control
      self$excludedCovariateConceptIds <- as.integer(excludedCovariateConceptIds)
      self$includedCovariateConceptIds <- as.integer(includedCovariateConceptIds)
      self$maxCohortSizeForFitting <- as.integer(maxCohortSizeForFitting)
      self$seed <- as.integer(seed)
      if (!is.null(json)) {
        super$initialize(json = json)
      }
    },

    #' @description Serialise to JSON (prior and control fields are omitted).
    toJson = function() {
      env <- self$.__enclos_env__$self
      nms <- setdiff(ls(env, sorted = TRUE), ".__enclos_env__")
      flds <- Filter(function(nm) {
        v <- env[[nm]]
        !is.function(v) && !inherits(v, c("cyclopsPrior", "cyclopsControl"))
      }, nms)
      result <- stats::setNames(lapply(flds, function(nm) env[[nm]]), flds)
      jsonlite::toJSON(result, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = 15)
    },

    #' @description Validate all fields using checkmate.
    validate = function() {
      errorMessages <- checkmate::makeAssertCollection()
      checkmate::assertIntegerish(
        self$excludedCovariateConceptIds,
        lower = 0L, null.ok = FALSE, add = errorMessages
      )
      checkmate::assertIntegerish(
        self$includedCovariateConceptIds,
        lower = 0L, null.ok = FALSE, add = errorMessages
      )
      checkmate::assertInt(self$maxCohortSizeForFitting, lower = 0L, add = errorMessages)
      checkmate::assertInt(self$seed, add = errorMessages)
      checkmate::reportAssertions(collection = errorMessages)
      invisible(self)
    }
  )
)

# ---- Factory ----------------------------------------------------------------

#' Create TCPS fitting arguments
#'
#' @description
#' Specifies all parameters for [fitTcps()], which fits a conditional logistic
#' regression (CLR) stratified by exposure set.
#'
#' @param prior (`cyclopsPrior`) A Cyclops prior object created with
#'   `Cyclops::createPrior()`. Defaults to a Laplace (LASSO) prior with
#'   cross-validation:
#'   `Cyclops::createPrior("laplace", variance = 0.01, useCrossValidation = TRUE)`.
#' @param control (`cyclopsControl`) A Cyclops control object created with
#'   `Cyclops::createControl()`. Defaults to
#'   `Cyclops::createControl(noiseLevel = "silent", cvType = "auto", fold = 10,
#'   startingVariance = 0.01, seed = 1L)`.
#' @param excludedCovariateConceptIds (`integer`) Concept IDs to exclude from
#'   the CLR (e.g. drugs on the causal pathway). Default: `integer(0)`.
#' @param includedCovariateConceptIds (`integer`) Concept IDs to include.
#'   Empty means all. Default: `integer(0)`.
#' @param maxCohortSizeForFitting (`integer(1)`) Maximum number of persons per
#'   treatment arm used for fitting. Persons beyond this limit are randomly
#'   sampled out. `0` means no limit. Default: `250000`.
#' @param seed (`integer(1)`) RNG seed used when downsampling the cohort.
#'   Default: `1`.
#'
#' @return A `TcpsArgs` R6 object.
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' \dontrun{
#' # Default settings (Laplace prior with cross-validation)
#' tcpsArgs <- createTcpsArgs()
#'
#' # Fast fitting for testing (fixed variance, no cross-validation)
#' tcpsArgs <- createTcpsArgs(
#'   prior   = Cyclops::createPrior("normal", variance = 0.1),
#'   control = Cyclops::createControl(noiseLevel = "silent")
#' )
#' }
#'
#' @export
createTcpsArgs <- function(prior = NULL,
                           control = NULL,
                           excludedCovariateConceptIds = integer(0),
                           includedCovariateConceptIds = integer(0),
                           maxCohortSizeForFitting = 250000L,
                           seed = 1L) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertIntegerish(
    excludedCovariateConceptIds,
    lower = 0L, null.ok = FALSE, add = errorMessages
  )
  checkmate::assertIntegerish(
    includedCovariateConceptIds,
    lower = 0L, null.ok = FALSE, add = errorMessages
  )
  checkmate::assertInt(maxCohortSizeForFitting, lower = 0L, add = errorMessages)
  checkmate::assertInt(seed, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  TcpsArgs$new(
    prior = prior,
    control = control,
    excludedCovariateConceptIds = as.integer(excludedCovariateConceptIds),
    includedCovariateConceptIds = as.integer(includedCovariateConceptIds),
    maxCohortSizeForFitting = as.integer(maxCohortSizeForFitting),
    seed = as.integer(seed)
  )
}

# ---- fitTcps ----------------------------------------------------------------

#' Fit a time-conditional propensity score model
#'
#' @description
#' Fits a conditional logistic regression (CLR) stratified by `exposure_set_id`
#' using Cyclops. The model estimates P(switch | covariates) — the probability
#' that a person switched to treatment B given their covariate history,
#' conditional on when they started treatment A.
#'
#' The returned data frame has the same rows as `population` plus a
#' `propensityScore` column containing P(treatment = 1 | covariates) estimated
#' from the linear predictor: `ps = 1 / (1 + exp(-β'x))`. Persons whose
#' `row_id` was downsampled out of the fitting step receive `NA`.
#'
#' @details
#' **No covariates** When the covariate table (after filtering) is empty, no
#' model is fit; all persons receive `propensityScore = 0.5` and a message is
#' issued.
#'
#' **Default prior** A Laplace (LASSO) prior with 10-fold cross-validation is
#' used when `tcpsArgs$prior` is `NULL`. A default Cyclops control (silent,
#' `cvType = "auto"`) is used when `tcpsArgs$control` is `NULL`.
#'
#' @param population A data frame from `dplyr::collect(pnuData$studyPopulation)`.
#'   Must contain columns `row_id`, `exposure_set_id`, and `treatment`.
#' @param pnuData A [PnuData] object providing the `covariates` and
#'   `covariateRef` tables.
#' @param tcpsArgs A `TcpsArgs` object from [createTcpsArgs()].
#'
#' @return `population` with an additional `propensityScore` column
#'   (`numeric`, range \[0, 1\]).
#'
#' @seealso [createTcpsArgs()], [createStudyPopulation()]
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' \dontrun{
#' simArgs <- createSimulationArgs(nSwitchers = 500L, nCovariates = 10L, seed = 1L)
#' pnuData <- simulatePnuData(simArgs)
#' spArgs <- createStudyPopulationArgs(outcomeId = 1L)
#' pnuData <- createStudyPopulation(pnuData, spArgs)
#' pop <- dplyr::collect(pnuData$studyPopulation)
#' tcpsArgs <- createTcpsArgs(
#'   prior   = Cyclops::createPrior("normal", variance = 0.1),
#'   control = Cyclops::createControl(noiseLevel = "silent")
#' )
#' pop <- fitTcps(pop, pnuData, tcpsArgs)
#' Andromeda::close(pnuData)
#' }
#'
#' @export
fitTcps <- function(population, pnuData, tcpsArgs) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertDataFrame(population, add = errorMessages)
  checkmate::assertNames(
    names(population),
    must.include = c("row_id", "exposure_set_id", "treatment"),
    add = errorMessages
  )
  checkmate::assertClass(pnuData, "PnuData", add = errorMessages)
  checkmate::assertClass(tcpsArgs, "TcpsArgs", add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  if (!requireNamespace("Cyclops", quietly = TRUE)) {
    stop("Package 'Cyclops' is required for fitTcps() but is not installed.")
  }

  # Collect covariates for this population only
  rowIds <- population$row_id
  covariates <- dplyr::collect(
    dplyr::filter(pnuData$covariates, .data$row_id %in% rowIds)
  )

  # Apply concept-ID inclusion/exclusion (requires covariateRef join)
  excl <- tcpsArgs$excludedCovariateConceptIds
  incl <- tcpsArgs$includedCovariateConceptIds
  if (length(excl) > 0L || length(incl) > 0L) {
    covRef <- dplyr::collect(pnuData$covariateRef) |>
      dplyr::select("covariate_id", "concept_id")
    covariates <- dplyr::left_join(covariates, covRef, by = "covariate_id")
    if (length(excl) > 0L) {
      covariates <- dplyr::filter(covariates, !(.data$concept_id %in% excl))
    }
    if (length(incl) > 0L) {
      covariates <- dplyr::filter(covariates, .data$concept_id %in% incl)
    }
    covariates <- dplyr::select(covariates, "row_id", "covariate_id", "covariate_value")
  }

  # No covariates: return flat score
  if (nrow(covariates) == 0L) {
    message("No covariates found; propensityScore set to 0.5 for all persons.")
    population$propensityScore <- 0.5
    return(population)
  }

  # Optional downsampling within each arm
  pop <- population
  maxN <- tcpsArgs$maxCohortSizeForFitting
  if (!is.na(maxN) && maxN > 0L) {
    swIdx <- which(pop$treatment == 1L)
    coIdx <- which(pop$treatment == 0L)
    if (length(swIdx) > maxN || length(coIdx) > maxN) {
      withr::with_seed(tcpsArgs$seed, {
        if (length(swIdx) > maxN) swIdx <- sample(swIdx, maxN)
        if (length(coIdx) > maxN) coIdx <- sample(coIdx, maxN)
      })
      pop <- pop[c(swIdx, coIdx), ]
    }
  }

  # Defaults for prior / control
  prior <- if (is.null(tcpsArgs$prior)) {
    Cyclops::createPrior("laplace", variance = 0.01, useCrossValidation = TRUE)
  } else {
    tcpsArgs$prior
  }
  control <- if (is.null(tcpsArgs$control)) {
    Cyclops::createControl(
      noiseLevel = "silent", cvType = "auto", fold = 10L,
      startingVariance = 0.01, seed = 1L
    )
  } else {
    tcpsArgs$control
  }

  # Build outcomes and covariates data frames for Cyclops CLR
  # Cyclops CLR requires stratumId in BOTH outcomes and covariates, sorted by stratumId
  outDf <- data.frame(
    stratumId = as.integer(pop$exposure_set_id),
    rowId     = as.integer(pop$row_id),
    y         = as.integer(pop$treatment)
  )
  outDf <- outDf[order(outDf$stratumId), ]

  # Restrict covariates to downsampled pop and add stratumId
  stratumMap <- data.frame(
    rowId     = as.integer(pop$row_id),
    stratumId = as.integer(pop$exposure_set_id)
  )
  covDf <- data.frame(
    rowId          = as.integer(covariates$row_id),
    covariateId    = as.numeric(covariates$covariate_id),
    covariateValue = as.numeric(covariates$covariate_value)
  ) |>
    merge(stratumMap, by = "rowId") |>
    (\(d) d[order(d$stratumId), c("stratumId", "rowId", "covariateId", "covariateValue")])()

  cyclopsData <- Cyclops::convertToCyclopsData(
    outcomes = outDf,
    covariates = covDf,
    modelType = "clr",
    addIntercept = FALSE,
    checkRowIds = FALSE
  )

  fit <- Cyclops::fitCyclopsModel(
    cyclopsData,
    prior   = prior,
    control = control
  )

  # predict() returns linear predictor β'x; convert to probability
  linearPredictor <- stats::predict(fit)
  ps_fitted <- 1.0 / (1.0 + exp(-linearPredictor))

  # Map scores back to full population (NA for downsampled-out persons)
  ps <- rep(NA_real_, nrow(population))
  matchIdx <- match(pop$row_id, population$row_id)
  ps[matchIdx] <- ps_fitted

  population$propensityScore <- ps
  population
}
