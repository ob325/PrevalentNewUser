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

# ---- BootstrapArgs ----------------------------------------------------------

#' Settings for bootstrap confidence intervals
#'
#' @description
#' Holds parameters controlling [bootstrapCi()]. Create with
#' [createBootstrapArgs()].
#'
#' @keywords internal
BootstrapArgs <- R6::R6Class(
  classname = "BootstrapArgs",
  inherit = AbstractSerializableSettings,
  cloneable = FALSE,
  public = list(
    #' @field numberOfReplications Number of bootstrap resamples.
    numberOfReplications = NULL,
    #' @field seed RNG seed for reproducible resampling.
    seed = NULL,
    #' @field cores Number of parallel workers (`1` = sequential).
    cores = NULL,

    #' @description Construct from named arguments or a JSON string.
    #' @param numberOfReplications,seed,cores See factory.
    #' @param json JSON string from `toJson()`.
    initialize = function(numberOfReplications = 1000L,
                          seed = 1L,
                          cores = 1L,
                          json = NULL) {
      self$numberOfReplications <- as.integer(numberOfReplications)
      self$seed <- as.integer(seed)
      self$cores <- as.integer(cores)
      if (!is.null(json)) super$initialize(json = json)
    },

    #' @description Validate all fields using checkmate.
    validate = function() {
      errorMessages <- checkmate::makeAssertCollection()
      checkmate::assertInt(self$numberOfReplications, lower = 1L, add = errorMessages)
      checkmate::assertInt(self$seed, add = errorMessages)
      checkmate::assertInt(self$cores, lower = 1L, add = errorMessages)
      checkmate::reportAssertions(collection = errorMessages)
      invisible(self)
    }
  )
)

# ---- Factory ----------------------------------------------------------------

#' Create bootstrap arguments
#'
#' @description
#' Specifies parameters for [bootstrapCi()].
#'
#' @param numberOfReplications (`integer(1)`) Number of bootstrap resamples.
#'   Default: `1000`.
#' @param seed (`integer(1)`) RNG seed for reproducible resampling. Default: `1`.
#' @param cores (`integer(1)`) Number of parallel workers. `1` (default) runs
#'   sequentially. Values > 1 use `parallel::mclapply` (Unix/macOS only; falls
#'   back to sequential on Windows).
#'
#' @return A `BootstrapArgs` R6 object.
#'
#' @seealso [bootstrapCi()]
#'
#' @examples
#' bootstrapArgs <- createBootstrapArgs()
#' bootstrapArgs <- createBootstrapArgs(numberOfReplications = 200L, seed = 42L)
#'
#' @export
createBootstrapArgs <- function(numberOfReplications = 1000L,
                                seed = 1L,
                                cores = 1L) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertInt(numberOfReplications, lower = 1L, add = errorMessages)
  checkmate::assertInt(seed, add = errorMessages)
  checkmate::assertInt(cores, lower = 1L, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  BootstrapArgs$new(
    numberOfReplications = as.integer(numberOfReplications),
    seed = as.integer(seed),
    cores = as.integer(cores)
  )
}

# ---- Internal helper --------------------------------------------------------

# Run one bootstrap replication: resample strata with replacement, renumber
# stratumIds, and refit the outcome model. Returns logRr or NA on failure.
.bootstrapOnce <- function(population, pnuData, outcomeModelArgs, stratumIds) {
  nStrata <- length(stratumIds)
  sampledStrata <- sample(stratumIds, nStrata, replace = TRUE)

  # Build resampled population with fresh sequential stratumIds
  chunks <- vector("list", nStrata)
  for (i in seq_len(nStrata)) {
    rows <- population[population$stratumId == sampledStrata[i], , drop = FALSE]
    rows$stratumId <- i
    chunks[[i]] <- rows
  }
  newPop <- do.call(rbind, chunks)

  # Reassign row_id: duplicate strata create duplicate row_ids, which Cyclops rejects
  newPop$row_id <- seq_len(nrow(newPop))

  result <- suppressWarnings(tryCatch(
    fitOutcomeModel(newPop, pnuData, outcomeModelArgs),
    error = function(e) list(status = "ERROR", logRr = NA_real_)
  ))

  if (identical(result$status, "OK")) result$logRr else NA_real_
}

# ---- bootstrapCi ------------------------------------------------------------

#' Bootstrap confidence intervals for the treatment effect
#'
#' @description
#' Estimates confidence intervals for the treatment log hazard (or odds / rate)
#' ratio using case-resampling bootstrap. Matched sets (strata identified by
#' `stratumId`) are resampled with replacement, preserving the matched
#' structure. The outcome model is refit on each resample.
#'
#' @details
#' The original point estimate (`logRr`) is the value from fitting
#' [fitOutcomeModel()] on the full (unbootstrapped) matched population. The
#' `seLogRr` is the standard deviation of the bootstrap distribution of
#' `logRr`. The `ci95Lb` and `ci95Ub` are 2.5th and 97.5th percentiles of the
#' bootstrap distribution (percentile method).
#'
#' Replications for which the outcome model fails to converge (e.g. strata with
#' no events after resampling) are dropped and a message is issued.
#'
#' Parallel execution (`cores > 1`) uses `parallel::mclapply` and is only
#' available on Unix/macOS. On Windows it falls back to sequential execution
#' silently.
#'
#' **Note:** This function can be slow. For `numberOfReplications = 1000` and
#' large populations, run time may be several minutes. Full production runs are
#' best placed in `extras/` scripts rather than in the test suite.
#'
#' @param population A data frame from [matchOnTcps()] with a `stratumId`
#'   column.
#' @param pnuData A [PnuData] object, or `NULL` when
#'   `outcomeModelArgs$useCovariates = FALSE`.
#' @param outcomeModelArgs An `OutcomeModelArgs` object from
#'   [createOutcomeModelArgs()].
#' @param bootstrapArgs A `BootstrapArgs` object from [createBootstrapArgs()].
#'
#' @return A named list with elements:
#' \describe{
#'   \item{`logRr`}{Log ratio from the full-data model.}
#'   \item{`seLogRr`}{Bootstrap standard error of `logRr`.}
#'   \item{`ci95Lb`}{Lower 95\% bootstrap percentile CI on the ratio scale.}
#'   \item{`ci95Ub`}{Upper 95\% bootstrap percentile CI on the ratio scale.}
#'   \item{`numberOfBootstraps`}{Number of successful replications used.}
#'   \item{`status`}{`"OK"` or description of failure.}
#' }
#'
#' @seealso [createBootstrapArgs()], [fitOutcomeModel()], [matchOnTcps()]
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
#' bootstrapArgs <- createBootstrapArgs(numberOfReplications = 200L, seed = 1L)
#' result <- bootstrapCi(matched, NULL, createOutcomeModelArgs(), bootstrapArgs)
#' Andromeda::close(pnuData)
#' }
#'
#' @export
bootstrapCi <- function(population, pnuData = NULL, outcomeModelArgs, bootstrapArgs) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertDataFrame(population, add = errorMessages)
  checkmate::assertNames(
    names(population),
    must.include = c("row_id", "treatment", "survival_time", "outcome_count", "stratumId"),
    add = errorMessages
  )
  if (!is.null(pnuData)) {
    checkmate::assertClass(pnuData, "PnuData", add = errorMessages)
  }
  checkmate::assertClass(outcomeModelArgs, "OutcomeModelArgs", add = errorMessages)
  checkmate::assertClass(bootstrapArgs, "BootstrapArgs", add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  if (outcomeModelArgs$useCovariates && is.null(pnuData)) {
    stop("useCovariates = TRUE requires a `pnuData` argument.")
  }

  emptyResult <- list(
    logRr = NA_real_,
    seLogRr = NA_real_,
    ci95Lb = NA_real_,
    ci95Ub = NA_real_,
    numberOfBootstraps = 0L,
    status = "NOT RUN"
  )

  # Fit original estimate on full population
  original <- fitOutcomeModel(population, pnuData, outcomeModelArgs)
  if (original$status != "OK") {
    emptyResult$status <- paste("ORIGINAL MODEL FAILED:", original$status)
    return(emptyResult)
  }

  stratumIds <- unique(population$stratumId)
  nReps <- bootstrapArgs$numberOfReplications

  message("Running ", nReps, " bootstrap replications...")

  # Run replications with withr to restore RNG state on exit
  useParallel <- bootstrapArgs$cores > 1L && .Platform$OS.type != "windows"

  bootLogRrs <- withr::with_seed(bootstrapArgs$seed, {
    if (useParallel) {
      unlist(parallel::mclapply(
        seq_len(nReps),
        function(i) .bootstrapOnce(population, pnuData, outcomeModelArgs, stratumIds),
        mc.cores = bootstrapArgs$cores
      ))
    } else {
      vapply(
        seq_len(nReps),
        function(i) .bootstrapOnce(population, pnuData, outcomeModelArgs, stratumIds),
        numeric(1L)
      )
    }
  })

  nFailed <- sum(is.na(bootLogRrs))
  if (nFailed > 0L) {
    message(nFailed, " bootstrap replication(s) failed (no events in resampled strata) and were excluded.")
  }
  bootLogRrs <- bootLogRrs[!is.na(bootLogRrs)]

  if (length(bootLogRrs) == 0L) {
    emptyResult$status <- "ALL BOOTSTRAP REPLICATIONS FAILED"
    return(emptyResult)
  }

  seLogRr <- stats::sd(bootLogRrs)
  ci95Lb <- as.numeric(exp(stats::quantile(bootLogRrs, 0.025)))
  ci95Ub <- as.numeric(exp(stats::quantile(bootLogRrs, 0.975)))

  ParallelLogger::logDebug(
    "bootstrapCi: logRr = ", round(original$logRr, 4),
    ", bootstrap seLogRr = ", round(seLogRr, 4),
    ", CI = [", round(ci95Lb, 4), ", ", round(ci95Ub, 4), "]"
  )

  list(
    logRr = original$logRr,
    seLogRr = seLogRr,
    ci95Lb = ci95Lb,
    ci95Ub = ci95Ub,
    numberOfBootstraps = length(bootLogRrs),
    status = "OK"
  )
}
