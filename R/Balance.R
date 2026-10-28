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

# ---- BalanceArgs -------------------------------------------------------------

#' Settings for covariate balance computation
#'
#' @description
#' Holds parameters controlling [computeCovariateBalance()]. Create with
#' [createBalanceArgs()].
#'
#' @keywords internal
BalanceArgs <- R6::R6Class(
  classname = "BalanceArgs",
  inherit = AbstractSerializableSettings,
  cloneable = FALSE,
  public = list(
    #' @field maxCohortSizeForBalance Maximum persons per arm used when
    #'   computing SMDs. Larger populations are randomly sampled. `0` = no
    #'   limit.
    maxCohortSizeForBalance = NULL,

    #' @description Construct from named arguments or a JSON string.
    #' @param maxCohortSizeForBalance See factory.
    #' @param json JSON string from `toJson()`.
    initialize = function(maxCohortSizeForBalance = 250000L,
                          json = NULL) {
      self$maxCohortSizeForBalance <- as.integer(maxCohortSizeForBalance)
      if (!is.null(json)) super$initialize(json = json)
    },

    #' @description Validate all fields using checkmate.
    validate = function() {
      errorMessages <- checkmate::makeAssertCollection()
      checkmate::assertInt(self$maxCohortSizeForBalance, lower = 0L, add = errorMessages)
      checkmate::reportAssertions(collection = errorMessages)
      invisible(self)
    }
  )
)

# ---- Factory ----------------------------------------------------------------

#' Create covariate balance arguments
#'
#' @description
#' Specifies parameters for [computeCovariateBalance()].
#'
#' @param maxCohortSizeForBalance (`integer(1)`) Maximum number of persons per
#'   treatment arm used when computing means. If either arm exceeds this, it is
#'   randomly down-sampled before balance is assessed. `0` disables the limit.
#'   Default: `250000`.
#'
#' @return A `BalanceArgs` R6 object.
#'
#' @seealso [computeCovariateBalance()]
#'
#' @examples
#' balanceArgs <- createBalanceArgs()
#' balanceArgs <- createBalanceArgs(maxCohortSizeForBalance = 50000L)
#'
#' @export
createBalanceArgs <- function(maxCohortSizeForBalance = 250000L) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertInt(maxCohortSizeForBalance, lower = 0L, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  BalanceArgs$new(maxCohortSizeForBalance = as.integer(maxCohortSizeForBalance))
}

# ---- Internal SMD helper ----------------------------------------------------

# Compute per-covariate weighted SMDs for a single population snapshot.
#
# pop        data.frame with row_id, treatment (1/0), weight (normalised per arm)
# covariates data.frame with row_id, covariate_id, covariate_value (sparse)
#
# Covariates are assumed binary: variance = mean * (1 - mean).
# Persons absent from the sparse covariate table contribute value = 0.
# Returns a tibble: covariate_id, mean_1, mean_0, smd.
.computeSmd <- function(pop, covariates) {
  if (nrow(pop) == 0L || nrow(covariates) == 0L) {
    return(dplyr::tibble(
      covariate_id = numeric(0),
      mean_1 = numeric(0),
      mean_0 = numeric(0),
      smd = numeric(0)
    ))
  }

  merged <- dplyr::inner_join(
    dplyr::select(pop, "row_id", "treatment", "weight"),
    dplyr::select(covariates, "row_id", "covariate_id", "covariate_value"),
    by = "row_id"
  )

  if (nrow(merged) == 0L) {
    return(dplyr::tibble(
      covariate_id = numeric(0),
      mean_1 = numeric(0),
      mean_0 = numeric(0),
      smd = numeric(0)
    ))
  }

  sums <- merged |>
    dplyr::group_by(.data$covariate_id, .data$treatment) |>
    dplyr::summarise(
      wMean = sum(.data$weight * .data$covariate_value, na.rm = TRUE),
      .groups = "drop"
    )

  sums1 <- dplyr::filter(sums, .data$treatment == 1L) |>
    dplyr::select("covariate_id", mean_1 = "wMean")
  sums0 <- dplyr::filter(sums, .data$treatment == 0L) |>
    dplyr::select("covariate_id", mean_0 = "wMean")

  dplyr::full_join(sums1, sums0, by = "covariate_id") |>
    dplyr::mutate(
      mean_1 = dplyr::coalesce(.data$mean_1, 0),
      mean_0 = dplyr::coalesce(.data$mean_0, 0),
      var_1 = .data$mean_1 * (1 - .data$mean_1),
      var_0 = .data$mean_0 * (1 - .data$mean_0),
      pooled_sd = sqrt((.data$var_1 + .data$var_0) / 2),
      smd = dplyr::if_else(
        .data$pooled_sd == 0,
        0,
        (.data$mean_1 - .data$mean_0) / .data$pooled_sd
      )
    ) |>
    dplyr::select("covariate_id", "mean_1", "mean_0", "smd")
}

# ---- computeCovariateBalance ------------------------------------------------

#' Compute covariate balance before and after matching
#'
#' @description
#' Computes the standardised mean difference (SMD) for each covariate before
#' matching (the full study population from [createStudyPopulation()]) and after
#' matching (the matched population from [matchOnTcps()]).
#'
#' @details
#' **Before matching** uses uniform per-arm weights (simple unweighted means).
#'
#' **After matching** uses stratum-size weights: each person in a matched set
#' of size \eqn{n_s} receives weight \eqn{1/n_s}, then weights are normalised
#' to sum to 1 within each arm. This mirrors CohortMethod's approach and gives
#' equal influence to each matched set, regardless of the number of comparators
#' matched per switcher.
#'
#' The SMD formula is
#' \deqn{SMD = \frac{\bar{x}_1 - \bar{x}_0}{\sqrt{(\hat{p}_1(1-\hat{p}_1) + \hat{p}_0(1-\hat{p}_0))/2}}}
#' using the Bernoulli pooled variance of the group means.
#'
#' The "before" population is read from `pnuData$studyPopulation`, which is
#' populated by [createStudyPopulation()] and is not modified by [matchOnTcps()].
#'
#' @param population A data frame from [matchOnTcps()] containing at minimum
#'   `row_id`, `treatment`, and `stratumId`.
#' @param pnuData A [PnuData] object providing `studyPopulation`, `covariates`,
#'   and `covariateRef` tables.
#' @param balanceArgs A `BalanceArgs` object from [createBalanceArgs()].
#'
#' @return A tibble with one row per covariate and columns:
#' \describe{
#'   \item{`covariateId`}{Numeric covariate identifier.}
#'   \item{`covariateName`}{Human-readable name from `covariateRef`.}
#'   \item{`beforeMatchingMeanTarget`}{Weighted mean in switchers before matching.}
#'   \item{`beforeMatchingMeanComparator`}{Weighted mean in comparators before matching.}
#'   \item{`beforeMatchingSmd`}{SMD before matching.}
#'   \item{`afterMatchingMeanTarget`}{Weighted mean in switchers after matching.}
#'   \item{`afterMatchingMeanComparator`}{Weighted mean in comparators after matching.}
#'   \item{`afterMatchingSmd`}{SMD after matching.}
#' }
#' Rows are sorted by descending `|beforeMatchingSmd|`.
#'
#' @seealso [createBalanceArgs()], [matchOnTcps()], [createStudyPopulation()]
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' \dontrun{
#' simArgs <- createSimulationArgs(
#'   nSwitchers = 500L, nCovariates = 5L,
#'   prevalenceDiff = 0.3, seed = 1L
#' )
#' pnuData <- simulatePnuData(simArgs)
#' pnuData <- createStudyPopulation(pnuData, createStudyPopulationArgs(outcomeId = 1L))
#' pop <- dplyr::collect(pnuData$studyPopulation)
#' pop <- fitTcps(
#'   pop, pnuData,
#'   createTcpsArgs(
#'     prior = Cyclops::createPrior("normal", variance = 0.1),
#'     control = Cyclops::createControl(noiseLevel = "silent")
#'   )
#' )
#' matched <- matchOnTcps(pop, createMatchingArgs())
#' balance <- computeCovariateBalance(matched, pnuData, createBalanceArgs())
#' Andromeda::close(pnuData)
#' }
#'
#' @export
computeCovariateBalance <- function(population, pnuData, balanceArgs) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertDataFrame(population, add = errorMessages)
  checkmate::assertNames(
    names(population),
    must.include = c("row_id", "treatment", "stratumId"),
    add = errorMessages
  )
  checkmate::assertClass(pnuData, "PnuData", add = errorMessages)
  checkmate::assertClass(balanceArgs, "BalanceArgs", add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  # --- Before-matching population: full studyPopulation ----------------------
  beforePop <- dplyr::collect(pnuData$studyPopulation) |>
    dplyr::select("row_id", "treatment")

  # Optional downsampling before balance
  maxN <- balanceArgs$maxCohortSizeForBalance
  if (!is.na(maxN) && maxN > 0L) {
    sw <- beforePop$row_id[beforePop$treatment == 1L]
    co <- beforePop$row_id[beforePop$treatment == 0L]
    if (length(sw) > maxN) sw <- sample(sw, maxN)
    if (length(co) > maxN) co <- sample(co, maxN)
    beforePop <- beforePop[beforePop$row_id %in% c(sw, co), ]
  }

  n1_before <- sum(beforePop$treatment == 1L)
  n0_before <- sum(beforePop$treatment == 0L)
  beforePop$weight <- ifelse(
    beforePop$treatment == 1L,
    if (n1_before > 0L) 1 / n1_before else 0,
    if (n0_before > 0L) 1 / n0_before else 0
  )

  # --- After-matching population: matched population with stratum weights -----
  afterPop <- population[, c("row_id", "treatment", "stratumId")]

  # Weight = 1 / n per (stratumId, treatment), then normalise within arm
  stratumCounts <- afterPop |>
    dplyr::count(.data$stratumId, .data$treatment, name = "n_in_stratum")
  afterPop <- dplyr::left_join(afterPop, stratumCounts, by = c("stratumId", "treatment"))
  rawW <- 1 / afterPop$n_in_stratum
  sumW1 <- sum(rawW[afterPop$treatment == 1L])
  sumW0 <- sum(rawW[afterPop$treatment == 0L])
  afterPop$weight <- ifelse(
    afterPop$treatment == 1L,
    if (sumW1 > 0) rawW / sumW1 else 0,
    if (sumW0 > 0) rawW / sumW0 else 0
  )

  # --- Collect covariates for each population --------------------------------
  beforeRowIds <- beforePop$row_id
  afterRowIds <- afterPop$row_id

  covBefore <- dplyr::collect(
    dplyr::filter(pnuData$covariates, .data$row_id %in% beforeRowIds)
  )
  covAfter <- dplyr::collect(
    dplyr::filter(pnuData$covariates, .data$row_id %in% afterRowIds)
  )

  # --- Compute SMDs ----------------------------------------------------------
  smdBefore <- .computeSmd(beforePop, covBefore)
  smdAfter <- .computeSmd(afterPop, covAfter)

  covRef <- dplyr::collect(pnuData$covariateRef) |>
    dplyr::select("covariate_id", "covariate_name")

  result <- dplyr::full_join(
    dplyr::rename(smdBefore,
      beforeMatchingMeanTarget = "mean_1",
      beforeMatchingMeanComparator = "mean_0",
      beforeMatchingSmd = "smd"
    ),
    dplyr::rename(smdAfter,
      afterMatchingMeanTarget = "mean_1",
      afterMatchingMeanComparator = "mean_0",
      afterMatchingSmd = "smd"
    ),
    by = "covariate_id"
  ) |>
    dplyr::left_join(covRef, by = "covariate_id") |>
    dplyr::select(
      "covariate_id", "covariate_name",
      "beforeMatchingMeanTarget", "beforeMatchingMeanComparator", "beforeMatchingSmd",
      "afterMatchingMeanTarget", "afterMatchingMeanComparator", "afterMatchingSmd"
    ) |>
    dplyr::arrange(dplyr::desc(abs(.data$beforeMatchingSmd)))

  result
}
