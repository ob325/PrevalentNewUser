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

# ---- calibrateEstimates -----------------------------------------------------

#' Apply empirical calibration to study estimates
#'
#' @description
#' Fits a systematic-error null distribution from a set of negative-control
#' estimates and uses it to calibrate p-values and confidence intervals for one
#' or more study estimates.
#'
#' @details
#' The null distribution is fitted with
#' [EmpiricalCalibration::fitNull()] (maximum-likelihood normal on the
#' logRr scale). The fitted null is then converted to a
#' `systematicErrorModel` with
#' [EmpiricalCalibration::convertNullToErrorModel()] before being passed to
#' [EmpiricalCalibration::calibrateConfidenceInterval()], which shifts and
#' inflates the estimate and its confidence interval to account for estimated
#' systematic error. Calibrated p-values come from
#' [EmpiricalCalibration::calibrateP()] (two-sided by default).
#'
#' Rows in `estimates` with non-finite `logRr` or `seLogRr` receive `NA` for
#' all calibrated columns. Negative controls with non-finite values are silently
#' dropped before fitting the null.
#'
#' @param estimates A data frame with at least columns `logRr` and `seLogRr`.
#'   Any additional columns are passed through unchanged.
#' @param negativeControlOutcomes A data frame with columns `logRr` and
#'   `seLogRr` for outcomes known to have no true association with the exposure
#'   (true log hazard ratio = 0). At least 2 complete rows are required.
#'
#' @return `estimates` with five additional columns:
#' \describe{
#'   \item{`calibratedLogRr`}{Bias-corrected point estimate on the log scale.}
#'   \item{`calibratedSeLogRr`}{Standard error of the calibrated log estimate.}
#'   \item{`calibratedP`}{Two-sided empirically calibrated p-value.}
#'   \item{`calibratedCi95Lb`}{Lower bound of the calibrated 95\% CI (ratio scale).}
#'   \item{`calibratedCi95Ub`}{Upper bound of the calibrated 95\% CI (ratio scale).}
#' }
#'
#' @references
#' Schuemie MJ, Ryan PB, DuMouchel W, Suchard MA, Madigan D. Interpreting
#' observational studies: why empirical calibration is needed to correct
#' p-values. *Stat Med* 2014;33(2):209-218. \doi{10.1002/sim.5925}
#'
#' Schuemie MJ, Hripcsak G, Ryan PB, Madigan D, Suchard MA. Robust empirical
#' calibration of p-values using observational data. *Stat Med*
#' 2016;35(22):3833-3844. \doi{10.1002/sim.6977}
#'
#' @examples
#' \dontrun{
#' negControls <- data.frame(
#'   logRr   = rnorm(100, mean = 0.05, sd = 0.15),
#'   seLogRr = rep(0.12, 100)
#' )
#' estimates <- data.frame(
#'   logRr   = c(0.35, -0.10),
#'   seLogRr = c(0.12, 0.12)
#' )
#' calibrated <- calibrateEstimates(estimates, negControls)
#' }
#'
#' @export
calibrateEstimates <- function(estimates, negativeControlOutcomes) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertDataFrame(estimates, add = errorMessages)
  checkmate::assertNames(
    names(estimates),
    must.include = c("logRr", "seLogRr"),
    add = errorMessages
  )
  checkmate::assertDataFrame(negativeControlOutcomes, add = errorMessages)
  checkmate::assertNames(
    names(negativeControlOutcomes),
    must.include = c("logRr", "seLogRr"),
    add = errorMessages
  )
  checkmate::reportAssertions(collection = errorMessages)

  ncComplete <- negativeControlOutcomes[
    is.finite(negativeControlOutcomes$logRr) &
      is.finite(negativeControlOutcomes$seLogRr),
  ]
  if (nrow(ncComplete) < 2L) {
    stop("At least 2 negative controls with finite logRr and seLogRr are required.")
  }

  # Fit null distribution on log-RR scale from negative controls
  null <- fitNull(
    logRr   = ncComplete$logRr,
    seLogRr = ncComplete$seLogRr
  )

  # Convert to systematic error model for confidence interval calibration
  model <- convertNullToErrorModel(null)

  nEst <- nrow(estimates)
  calibratedLogRr <- rep(NA_real_, nEst)
  calibratedSeLogRr <- rep(NA_real_, nEst)
  calibratedP <- rep(NA_real_, nEst)
  calibratedCi95Lb <- rep(NA_real_, nEst)
  calibratedCi95Ub <- rep(NA_real_, nEst)

  complete <- is.finite(estimates$logRr) & is.finite(estimates$seLogRr)

  if (any(complete)) {
    ci <- calibrateConfidenceInterval(
      logRr   = estimates$logRr[complete],
      seLogRr = estimates$seLogRr[complete],
      model   = model
    )
    calibratedLogRr[complete] <- ci$logRr
    calibratedSeLogRr[complete] <- ci$seLogRr
    calibratedCi95Lb[complete] <- exp(ci$logLb95Rr)
    calibratedCi95Ub[complete] <- exp(ci$logUb95Rr)

    calibratedP[complete] <- calibrateP(
      null    = null,
      logRr   = estimates$logRr[complete],
      seLogRr = estimates$seLogRr[complete]
    )
  }

  dplyr::bind_cols(
    estimates,
    dplyr::tibble(
      calibratedLogRr   = calibratedLogRr,
      calibratedSeLogRr = calibratedSeLogRr,
      calibratedP       = calibratedP,
      calibratedCi95Lb  = calibratedCi95Lb,
      calibratedCi95Ub  = calibratedCi95Ub
    )
  )
}
