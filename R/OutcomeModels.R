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

# ---- OutcomeModelArgs -------------------------------------------------------

#' Settings for outcome model fitting
#'
#' @description
#' Holds parameters controlling [fitOutcomeModel()]. Create with
#' [createOutcomeModelArgs()].
#'
#' The `prior` and `control` fields are Cyclops objects and are omitted from
#' JSON serialization (same pattern as [TcpsArgs]).
#'
#' @keywords internal
OutcomeModelArgs <- R6::R6Class(
  classname = "OutcomeModelArgs",
  inherit = AbstractSerializableSettings,
  cloneable = FALSE,
  public = list(
    #' @field modelType Outcome model type: `"cox"`, `"logistic"`, or `"poisson"`.
    modelType = NULL,
    #' @field stratified Stratify on `stratumId` (matched sets)?
    stratified = NULL,
    #' @field useCovariates Include covariates from `pnuData` in the outcome model?
    useCovariates = NULL,
    #' @field prior Cyclops prior (`cyclopsPrior`), or `NULL` for default.
    prior = NULL,
    #' @field control Cyclops control (`cyclopsControl`), or `NULL` for default.
    control = NULL,

    #' @description Construct from named arguments or a JSON string.
    #' @param modelType,stratified,useCovariates,prior,control See factory.
    #' @param json JSON string from `toJson()`. `prior` and `control` are not
    #'   restored; supply them again via [createOutcomeModelArgs()].
    initialize = function(modelType = "cox",
                          stratified = TRUE,
                          useCovariates = FALSE,
                          prior = NULL,
                          control = NULL,
                          json = NULL) {
      self$modelType <- modelType
      self$stratified <- stratified
      self$useCovariates <- useCovariates
      self$prior <- prior
      self$control <- control
      if (!is.null(json)) super$initialize(json = json)
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
      checkmate::assertChoice(self$modelType, c("cox", "logistic", "poisson"), add = errorMessages)
      checkmate::assertLogical(self$stratified, len = 1L, add = errorMessages)
      checkmate::assertLogical(self$useCovariates, len = 1L, add = errorMessages)
      checkmate::reportAssertions(collection = errorMessages)
      invisible(self)
    }
  )
)

# ---- Factory ----------------------------------------------------------------

#' Create outcome model arguments
#'
#' @description
#' Specifies all parameters for [fitOutcomeModel()], which fits a regression
#' model for the outcome on the matched (or stratified) study population.
#'
#' @param modelType (`character(1)`) One of `"cox"` (default), `"logistic"`,
#'   or `"poisson"`.
#' @param stratified (`logical(1)`) Whether to stratify by `stratumId`
#'   (matched set). `TRUE` (default) uses conditional Cox / logistic / Poisson;
#'   `FALSE` fits an unconditional model. Stratification requires that
#'   [matchOnTcps()] has been run.
#' @param useCovariates (`logical(1)`) If `TRUE`, include all covariates from
#'   `pnuData` as additional adjusters in the outcome model (doubly-robust
#'   approach). Default: `FALSE`.
#' @param prior (`cyclopsPrior`) Cyclops prior for the covariate coefficients
#'   when `useCovariates = TRUE`. The treatment coefficient is always
#'   unpenalised. Ignored when `useCovariates = FALSE`. `NULL` uses a Laplace
#'   prior with cross-validation.
#' @param control (`cyclopsControl`) Cyclops control specification. `NULL` uses
#'   the Cyclops default.
#'
#' @return An `OutcomeModelArgs` R6 object.
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' \dontrun{
#' # Default: stratified Cox, treatment effect only
#' outcomeModelArgs <- createOutcomeModelArgs()
#'
#' # Doubly-robust: also adjust for covariates in the outcome model
#' outcomeModelArgs <- createOutcomeModelArgs(useCovariates = TRUE)
#' }
#'
#' @export
createOutcomeModelArgs <- function(modelType = "cox",
                                   stratified = TRUE,
                                   useCovariates = FALSE,
                                   prior = NULL,
                                   control = NULL) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertChoice(modelType, c("cox", "logistic", "poisson"), add = errorMessages)
  checkmate::assertLogical(stratified, len = 1L, add = errorMessages)
  checkmate::assertLogical(useCovariates, len = 1L, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  OutcomeModelArgs$new(
    modelType = modelType,
    stratified = stratified,
    useCovariates = useCovariates,
    prior = prior,
    control = control
  )
}

# ---- Internal helpers -------------------------------------------------------

# Map modelType + stratified to Cyclops model type string
.toCyclopsModelType <- function(modelType, stratified) {
  if (modelType == "cox") {
    return("cox")
  } else if (modelType == "logistic") {
    return(if (stratified) "clr" else "lr")
  } else if (modelType == "poisson") {
    return(if (stratified) "cpr" else "pr")
  }
  stop(paste("Unknown modelType:", modelType))
}

# Reduce to strata that have at least one event and both treatment arms present.
# For unstratified models, return all rows.
.getInformativePopulation <- function(pop, modelType, stratified) {
  pop$y <- as.integer(pop$outcome_count > 0L)

  if (modelType == "cox") {
    # Survival time must be > 0
    pop <- pop[pop$survival_time > 0L, ]
    pop$time <- as.numeric(pop$survival_time)
  } else if (modelType == "logistic") {
    pop$time <- NULL
  } else if (modelType == "poisson") {
    pop$time <- as.numeric(pop$survival_time)
  }

  if (stratified) {
    withEvent <- unique(pop$stratumId[pop$y != 0L])
    pop <- pop[pop$stratumId %in% withEvent, ]
  }

  pop
}

# ---- fitOutcomeModel --------------------------------------------------------

#' Fit an outcome model on the matched population
#'
#' @description
#' Fits a regression model for the outcome using Cyclops. By default, a
#' stratified Cox proportional-hazards model stratified by `stratumId` (matched
#' set) is used, which is the standard analysis for the prevalent new-user
#' design.
#'
#' @details
#' Only strata with at least one outcome event contribute to the stratified
#' model likelihood. Strata with zero events are dropped before fitting
#' (standard partial-likelihood behaviour).
#'
#' The treatment estimate is the coefficient for the binary `treatment`
#' covariate. When `useCovariates = FALSE` (default), no other covariates are
#' included and no regularization is applied (`prior = "none"`). When
#' `useCovariates = TRUE`, all covariates from `pnuData$covariates` are
#' included as additional adjusters; the treatment coefficient remains
#' unpenalised.
#'
#' @param population A data frame from [matchOnTcps()] containing `row_id`,
#'   `treatment`, `stratumId`, `survival_time`, and `outcome_count`.
#' @param pnuData A [PnuData] object. Required when `useCovariates = TRUE`
#'   (for `covariates` and `covariateRef` tables).
#' @param outcomeModelArgs An `OutcomeModelArgs` object from
#'   [createOutcomeModelArgs()].
#'
#' @return A named list of class `"OutcomeModel"` with elements:
#' \describe{
#'   \item{`logRr`}{Log hazard (or odds / rate) ratio for the treatment.}
#'   \item{`seLogRr`}{Standard error of `logRr`, derived from the profile CI.}
#'   \item{`p`}{Two-sided p-value.}
#'   \item{`ci95Lb`}{Lower bound of the 95\% confidence interval on the ratio scale.}
#'   \item{`ci95Ub`}{Upper bound of the 95\% confidence interval on the ratio scale.}
#'   \item{`status`}{`"OK"` or a description of why the model could not be fit.}
#'   \item{`outcomeModelType`}{Value of `modelType`.}
#'   \item{`outcomeModelStratified`}{Value of `stratified`.}
#' }
#'
#' @seealso [createOutcomeModelArgs()], [matchOnTcps()]
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' \dontrun{
#' simArgs <- createSimulationArgs(
#'   nSwitchers = 500L, nCovariates = 0L,
#'   logRr = log(2), seed = 1L
#' )
#' pnuData <- simulatePnuData(simArgs)
#' pnuData <- createStudyPopulation(pnuData, createStudyPopulationArgs(outcomeId = 1L))
#' pop <- dplyr::collect(pnuData$studyPopulation)
#' pop$propensityScore <- 0.5
#' matched <- matchOnTcps(pop, createMatchingArgs())
#' result <- fitOutcomeModel(matched, pnuData, createOutcomeModelArgs())
#' Andromeda::close(pnuData)
#' }
#'
#' @export
fitOutcomeModel <- function(population, pnuData = NULL, outcomeModelArgs) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertDataFrame(population, add = errorMessages)
  checkmate::assertNames(
    names(population),
    must.include = c("row_id", "treatment", "survival_time", "outcome_count"),
    add = errorMessages
  )
  if (!is.null(pnuData)) {
    checkmate::assertClass(pnuData, "PnuData", add = errorMessages)
  }
  checkmate::assertClass(outcomeModelArgs, "OutcomeModelArgs", add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  if (!requireNamespace("Cyclops", quietly = TRUE)) {
    stop("Package 'Cyclops' is required for fitOutcomeModel() but is not installed.")
  }

  if (outcomeModelArgs$stratified && !"stratumId" %in% names(population)) {
    stop(
      "Requested stratified model but `stratumId` column not found. ",
      "Run matchOnTcps() before fitOutcomeModel()."
    )
  }
  if (outcomeModelArgs$useCovariates && is.null(pnuData)) {
    stop("useCovariates = TRUE requires a `pnuData` argument.")
  }

  # Build return skeleton
  result <- list(
    logRr = NA_real_,
    seLogRr = NA_real_,
    p = NA_real_,
    ci95Lb = NA_real_,
    ci95Ub = NA_real_,
    status = "NO MODEL FITTED",
    outcomeModelType = outcomeModelArgs$modelType,
    outcomeModelStratified = outcomeModelArgs$stratified
  )
  class(result) <- "OutcomeModel"

  if (nrow(population) == 0L) {
    result$status <- "NO SUBJECTS IN POPULATION"
    return(result)
  }
  if (sum(population$outcome_count) == 0L) {
    result$status <- "NO OUTCOMES IN POPULATION"
    return(result)
  }

  # Reduce to informative population
  pop <- .getInformativePopulation(
    population,
    outcomeModelArgs$modelType,
    outcomeModelArgs$stratified
  )

  if (nrow(pop) == 0L ||
    sum(pop$treatment == 1L) == 0L ||
    sum(pop$treatment == 0L) == 0L) {
    result$status <- "NO INFORMATIVE STRATA WITH BOTH ARMS AND AN OUTCOME"
    return(result)
  }

  # Build Cyclops outcomes data frame
  outDf <- data.frame(
    rowId = as.integer(pop$row_id),
    y = pop$y,
    stringsAsFactors = FALSE
  )
  if (outcomeModelArgs$modelType %in% c("cox", "poisson")) {
    outDf$time <- pop$time
  }
  if (outcomeModelArgs$stratified) {
    outDf$stratumId <- as.integer(pop$stratumId)
    outDf <- outDf[order(outDf$stratumId), ]
  }

  # Treatment covariate (ID = 1 when useCovariates = FALSE)
  treatmentVarId <- 1L

  if (outcomeModelArgs$useCovariates) {
    # Collect and assign treatment a unique ID above all covariate IDs
    covRef <- dplyr::collect(pnuData$covariateRef)
    if (nrow(covRef) > 0L) {
      treatmentVarId <- as.integer(max(covRef$covariate_id)) + 1L
    }
    covDf <- dplyr::collect(
      dplyr::filter(pnuData$covariates, .data$row_id %in% pop$row_id)
    )
    covDf <- data.frame(
      rowId = as.integer(covDf$row_id),
      covariateId = as.numeric(covDf$covariate_id),
      covariateValue = as.numeric(covDf$covariate_value),
      stringsAsFactors = FALSE
    )
    treatDf <- data.frame(
      rowId = as.integer(pop$row_id),
      covariateId = as.numeric(treatmentVarId),
      covariateValue = as.numeric(pop$treatment),
      stringsAsFactors = FALSE
    )
    covDf <- rbind(covDf, treatDf)
    prior <- if (is.null(outcomeModelArgs$prior)) {
      Cyclops::createPrior("laplace",
        variance = 0.01, useCrossValidation = TRUE,
        exclude = treatmentVarId
      )
    } else {
      p <- outcomeModelArgs$prior
      p$exclude <- c(p$exclude, treatmentVarId)
      p
    }
  } else {
    covDf <- data.frame(
      rowId = as.integer(pop$row_id),
      covariateId = as.numeric(treatmentVarId),
      covariateValue = as.numeric(pop$treatment),
      stringsAsFactors = FALSE
    )
    prior <- Cyclops::createPrior("none")
  }

  if (outcomeModelArgs$stratified) {
    # Add stratumId to covDf for Cyclops CLR/CPR models
    # (cox model does not require stratumId in covariates, but it's needed for clr/cpr)
    cyclopsModelType <- .toCyclopsModelType(outcomeModelArgs$modelType, outcomeModelArgs$stratified)
    if (cyclopsModelType %in% c("clr", "cpr")) {
      stratumMap <- data.frame(
        rowId = as.integer(pop$row_id),
        stratumId = as.integer(pop$stratumId)
      )
      covDf <- merge(covDf, stratumMap, by = "rowId")
      covDf <- covDf[order(covDf$stratumId), c("stratumId", "rowId", "covariateId", "covariateValue")]
    }
  }

  cyclopsModelType <- .toCyclopsModelType(outcomeModelArgs$modelType, outcomeModelArgs$stratified)
  addIntercept <- (!outcomeModelArgs$stratified && outcomeModelArgs$modelType != "cox")

  cyclopsData <- tryCatch(
    Cyclops::convertToCyclopsData(
      outcomes = outDf,
      covariates = covDf,
      modelType = cyclopsModelType,
      addIntercept = addIntercept,
      checkRowIds = FALSE
    ),
    error = function(e) e
  )
  if (inherits(cyclopsData, "error")) {
    result$status <- paste("CYCLOPS DATA CONVERSION FAILED:", conditionMessage(cyclopsData))
    return(result)
  }

  control <- if (is.null(outcomeModelArgs$control)) {
    Cyclops::createControl(noiseLevel = "silent")
  } else {
    outcomeModelArgs$control
  }

  fit <- tryCatch(
    Cyclops::fitCyclopsModel(cyclopsData, prior = prior, control = control),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    result$status <- paste("MODEL FIT FAILED:", conditionMessage(fit))
    return(result)
  }

  coefs <- stats::coef(fit)
  treatKey <- as.character(treatmentVarId)
  if (!treatKey %in% names(coefs) || is.na(coefs[[treatKey]])) {
    result$status <- "TREATMENT COEFFICIENT NOT ESTIMABLE"
    return(result)
  }

  logRr <- as.numeric(coefs[[treatKey]])
  ci <- tryCatch(
    as.numeric(stats::confint(fit, parm = treatmentVarId, includePenalty = FALSE)),
    error = function(e) c(NA_real_, NA_real_, NA_real_)
  )

  ci95Lb <- exp(ci[2])
  ci95Ub <- exp(ci[3])
  seLogRr <- (ci[3] - ci[2]) / (2 * stats::qnorm(0.975))
  p <- 2 * stats::pnorm(abs(logRr / seLogRr), lower.tail = FALSE)

  result$logRr <- logRr
  result$seLogRr <- seLogRr
  result$p <- p
  result$ci95Lb <- ci95Lb
  result$ci95Ub <- ci95Ub
  result$status <- "OK"

  ParallelLogger::logDebug(
    "fitOutcomeModel: logRr = ", round(logRr, 4),
    ", seLogRr = ", round(seLogRr, 4),
    ", p = ", round(p, 4)
  )

  result
}

#' @export
print.OutcomeModel <- function(x, ...) {
  cli::cat_line(pillar::style_subtle("# OutcomeModel"))
  cli::cat_line(paste("Status:    ", x$status))
  cli::cat_line(paste(
    "Model type:", x$outcomeModelType,
    if (x$outcomeModelStratified) "(stratified)" else "(unstratified)"
  ))
  if (x$status == "OK") {
    cli::cat_line(paste("logRr:     ", round(x$logRr, 4)))
    cli::cat_line(paste("seLogRr:   ", round(x$seLogRr, 4)))
    cli::cat_line(paste(
      "HR [95% CI]:", round(exp(x$logRr), 3),
      "[", round(x$ci95Lb, 3), "-", round(x$ci95Ub, 3), "]"
    ))
    cli::cat_line(paste("p:         ", round(x$p, 4)))
  }
  invisible(x)
}
