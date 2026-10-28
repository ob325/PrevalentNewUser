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

# ---- MatchingArgs -----------------------------------------------------------

#' Settings for TCPS matching
#'
#' @description
#' Holds parameters controlling [matchOnTcps()]. Create with [createMatchingArgs()].
#'
#' @keywords internal
MatchingArgs <- R6::R6Class(
  classname = "MatchingArgs",
  inherit = AbstractSerializableSettings,
  cloneable = FALSE,
  public = list(
    #' @field caliper Caliper width as a fraction of the SD of the logit-PS (or
    #'   in logit units when `caliperScale = "logit"`). `0` disables the caliper.
    caliper = NULL,
    #' @field caliperScale Scale on which the caliper is applied.
    caliperScale = NULL,
    #' @field maxRatio Maximum number of comparators per switcher. `0` = variable
    #'   ratio (match all within caliper).
    maxRatio = NULL,
    #' @field allowReverseMatch If `TRUE` and a set has more switchers than
    #'   comparators, flip labels so the minority arm is matched to the majority.
    allowReverseMatch = NULL,

    #' @description Construct from named arguments or a JSON string.
    #' @param caliper,caliperScale,maxRatio,allowReverseMatch See factory.
    #' @param json JSON string from `toJson()`.
    initialize = function(caliper = 0.2,
                          caliperScale = "standardized logit",
                          maxRatio = 1L,
                          allowReverseMatch = FALSE,
                          json = NULL) {
      self$caliper <- caliper
      self$caliperScale <- caliperScale
      self$maxRatio <- as.integer(maxRatio)
      self$allowReverseMatch <- allowReverseMatch
      if (!is.null(json)) super$initialize(json = json)
    },

    #' @description Validate all fields using checkmate.
    validate = function() {
      errorMessages <- checkmate::makeAssertCollection()
      checkmate::assertNumber(self$caliper, lower = 0, add = errorMessages)
      checkmate::assertChoice(
        self$caliperScale,
        c("standardized logit", "logit"),
        add = errorMessages
      )
      checkmate::assertInt(self$maxRatio, lower = 0L, add = errorMessages)
      checkmate::assertLogical(self$allowReverseMatch, len = 1L, add = errorMessages)
      checkmate::reportAssertions(collection = errorMessages)
      invisible(self)
    }
  )
)

# ---- Factory ----------------------------------------------------------------

#' Create matching arguments
#'
#' @description
#' Specifies all parameters for [matchOnTcps()], which performs greedy
#' nearest-neighbour matching of switchers to comparators within each exposure
#' set using the time-conditional propensity score.
#'
#' @param caliper (`numeric(1)`) Caliper width. When `caliperScale =
#'   "standardized logit"` (default), this is a fraction of the pooled SD of
#'   the logit-PS across the whole population. When `caliperScale = "logit"`,
#'   it is an absolute width in logit units. `0` disables the caliper (match
#'   the globally nearest comparator). Default: `0.2`.
#' @param caliperScale (`character(1)`) One of `"standardized logit"` (default)
#'   or `"logit"`.
#' @param maxRatio (`integer(1)`) Maximum number of comparators matched to each
#'   switcher. `0` means variable ratio: every available comparator within the
#'   caliper is matched. Default: `1`.
#' @param allowReverseMatch (`logical(1)`) If `TRUE` and a set has more
#'   switchers than comparators, flip roles so the minority arm (comparators) is
#'   indexed and each comparator finds up to `maxRatio` switcher matches. The
#'   treatment column in the returned population is restored to its original
#'   labels. Default: `FALSE`.
#'
#' @return A `MatchingArgs` R6 object.
#'
#' @seealso [matchOnTcps()]
#'
#' @examples
#' # Default 1:1 matching with 0.2 standardized-logit caliper
#' matchingArgs <- createMatchingArgs()
#'
#' # 1:2 matching (up to two comparators per switcher)
#' matchingArgs <- createMatchingArgs(maxRatio = 2L)
#'
#' # Variable-ratio matching (all within caliper)
#' matchingArgs <- createMatchingArgs(maxRatio = 0L)
#'
#' @export
createMatchingArgs <- function(caliper = 0.2,
                               caliperScale = "standardized logit",
                               maxRatio = 1L,
                               allowReverseMatch = FALSE) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertNumber(caliper, lower = 0, add = errorMessages)
  checkmate::assertChoice(caliperScale, c("standardized logit", "logit"), add = errorMessages)
  checkmate::assertInt(maxRatio, lower = 0L, add = errorMessages)
  checkmate::assertLogical(allowReverseMatch, len = 1L, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  MatchingArgs$new(
    caliper = caliper,
    caliperScale = caliperScale,
    maxRatio = as.integer(maxRatio),
    allowReverseMatch = allowReverseMatch
  )
}

# ---- Internal matching helper -----------------------------------------------

# Greedy nearest-neighbour matching within a single stratum.
#
# ps        numeric vector of matching-scale PS values (logit or raw)
# treatment integer vector: 1 = case, 0 = control
# maxRatio  integer: max controls per case (already converted: 0 → 999)
# caliper   numeric: caliper width in same units as ps (Inf = no caliper)
#
# Returns an integer stratumId vector of the same length as ps.
# Unmatched positions receive -1L.
.greedyMatchInSet <- function(ps, treatment, maxRatio, caliper) {
  n <- length(ps)
  stratumId <- rep(-1L, n)

  casePos <- which(treatment == 1L)
  ctrlPos <- which(treatment == 0L)

  if (length(casePos) == 0L || length(ctrlPos) == 0L) {
    return(stratumId)
  }

  # Sort cases and controls by PS for ordered processing + binary-search range queries
  caseOrd <- casePos[order(ps[casePos])]
  ctrlOrd <- ctrlPos[order(ps[ctrlPos])]
  ctrlPs <- ps[ctrlOrd]

  ctrlUsed <- logical(length(ctrlOrd))
  stratumCounter <- 0L

  for (i in seq_along(caseOrd)) {
    ci <- caseOrd[i]
    psi <- ps[ci]

    # Binary-search bounds for controls within caliper
    lo <- findInterval(psi - caliper, ctrlPs)
    hi <- findInterval(psi + caliper, ctrlPs)

    # Include a control at exactly the lower boundary (distance == caliper)
    start_j <- if (lo >= 1L && ctrlPs[lo] >= psi - caliper) lo else lo + 1L
    end_j <- hi

    if (start_j > end_j) next

    window <- start_j:end_j
    avail <- window[!ctrlUsed[window]]

    if (length(avail) == 0L) next

    # Pick up to maxRatio nearest controls
    dists <- abs(ctrlPs[avail] - psi)
    avail <- avail[order(dists)]
    avail <- utils::head(avail, maxRatio)

    matchedCtrl <- ctrlOrd[avail]
    stratumCounter <- stratumCounter + 1L
    stratumId[ci] <- stratumCounter
    stratumId[matchedCtrl] <- stratumCounter
    ctrlUsed[avail] <- TRUE
  }

  stratumId
}

# ---- matchOnTcps ------------------------------------------------------------

#' Match on the time-conditional propensity score
#'
#' @description
#' Performs greedy nearest-neighbour matching of switchers to comparators within
#' each exposure set using the `propensityScore` column produced by [fitTcps()].
#' Unmatched persons are dropped. Returns the matched population with a new
#' `stratumId` column that identifies each matched set (used as the stratum in
#' outcome models).
#'
#' @details
#' The caliper is computed once across all exposure sets. When
#' `caliperScale = "standardized logit"` (default), the caliper width is
#' `caliper * SD(logit(PS))` pooled across the full population. This mirrors
#' CohortMethod's behaviour.
#'
#' Within each exposure set, cases (switchers, `treatment = 1`) are processed
#' in ascending PS order. For each case, all available comparators within the
#' caliper are identified; the nearest (up to `maxRatio`) are selected and
#' assigned the same stratum ID. Stratum IDs are unique integers across the
#' whole returned population.
#'
#' @param population A data frame (typically `dplyr::collect(pnuData$studyPopulation)`)
#'   with a `propensityScore` column added by [fitTcps()]. Must contain
#'   `row_id`, `treatment`, `exposure_set_id`, and `propensityScore`.
#' @param matchingArgs A `MatchingArgs` object from [createMatchingArgs()].
#'
#' @return `population` filtered to matched persons and with an additional
#'   integer `stratumId` column. Each stratum contains exactly one switcher
#'   and one to `maxRatio` comparators (or all within-caliper comparators when
#'   `maxRatio = 0`).
#'
#' @seealso [createMatchingArgs()], [fitTcps()]
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' \dontrun{
#' simArgs <- createSimulationArgs(nSwitchers = 500L, nCovariates = 5L, seed = 1L)
#' pnuData <- simulatePnuData(simArgs)
#' spArgs <- createStudyPopulationArgs(outcomeId = 1L)
#' pnuData <- createStudyPopulation(pnuData, spArgs)
#' pop <- dplyr::collect(pnuData$studyPopulation)
#' tcpsArgs <- createTcpsArgs(
#'   prior   = Cyclops::createPrior("normal", variance = 0.1),
#'   control = Cyclops::createControl(noiseLevel = "silent")
#' )
#' pop <- fitTcps(pop, pnuData, tcpsArgs)
#' matchingArgs <- createMatchingArgs(caliper = 0.2, maxRatio = 1L)
#' matched <- matchOnTcps(pop, matchingArgs)
#' Andromeda::close(pnuData)
#' }
#'
#' @export
matchOnTcps <- function(population, matchingArgs) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertDataFrame(population, add = errorMessages)
  checkmate::assertNames(
    names(population),
    must.include = c("row_id", "treatment", "exposure_set_id", "propensityScore"),
    add = errorMessages
  )
  checkmate::assertClass(matchingArgs, "MatchingArgs", add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  # Exclude rows with NA propensityScore (downsampled-out persons from fitTcps)
  naPs <- is.na(population$propensityScore)
  if (any(naPs)) {
    message(sum(naPs), " person(s) with NA propensityScore excluded before matching.")
    population <- population[!naPs, ]
  }

  if (nrow(population) == 0L) {
    population$stratumId <- integer(0L)
    return(population)
  }

  # Compute logit-PS (clamp PS from 0/1 to avoid ±Inf)
  ps <- pmin(pmax(population$propensityScore, 1e-6), 1 - 1e-6)
  logitPs <- log(ps / (1 - ps))

  # Caliper width on the logit scale (pooled across all sets)
  finite <- logitPs[is.finite(logitPs)]
  caliperWidth <- if (matchingArgs$caliper <= 0 || length(finite) < 2L) {
    Inf
  } else if (matchingArgs$caliperScale == "standardized logit") {
    matchingArgs$caliper * stats::sd(finite)
  } else {
    # "logit" — absolute width
    matchingArgs$caliper
  }

  maxRatio <- if (matchingArgs$maxRatio == 0L) 999L else matchingArgs$maxRatio

  # Match within each exposure set
  stratumId <- rep(-1L, nrow(population))
  globalOffset <- 0L

  setIds <- sort(unique(population$exposure_set_id))
  for (sid in setIds) {
    inSet <- which(population$exposure_set_id == sid)
    setPs <- logitPs[inSet]
    setTreat <- population$treatment[inSet]

    nCases <- sum(setTreat == 1L)
    nCtrls <- sum(setTreat == 0L)

    # Flip labels if allowed and cases outnumber controls (match minority → majority)
    reverseTreat <- matchingArgs$allowReverseMatch && nCases > nCtrls
    if (reverseTreat) setTreat <- 1L - setTreat

    setStratum <- .greedyMatchInSet(setPs, setTreat, maxRatio, caliperWidth)

    # Renumber matched strata with global offset to keep IDs unique across sets
    matched <- setStratum != -1L
    if (any(matched)) {
      setStratum[matched] <- setStratum[matched] + globalOffset
      globalOffset <- max(setStratum[matched])
    }

    stratumId[inSet] <- setStratum
  }

  population$stratumId <- stratumId

  # Drop unmatched persons
  population <- population[population$stratumId != -1L, ]

  ParallelLogger::logDebug(
    "Population size after matching: ", nrow(population),
    " (", sum(population$treatment == 1L), " switchers, ",
    sum(population$treatment == 0L), " comparators)"
  )

  population
}
