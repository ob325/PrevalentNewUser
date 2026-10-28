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

# ---- StudyPopulationArgs ----------------------------------------------------

#' Settings for study population creation
#'
#' @description
#' Holds all parameters controlling [createStudyPopulation()]. Create with
#' [createStudyPopulationArgs()].
#'
#' @keywords internal
StudyPopulationArgs <- R6::R6Class(
  classname = "StudyPopulationArgs",
  inherit = AbstractSerializableSettings,
  cloneable = FALSE,
  public = list(
    #' @field outcomeId Outcome cohort ID to index the study population on.
    outcomeId = NULL,
    #' @field firstExposureOnly Keep only the earliest cohort entry per person per arm.
    firstExposureOnly = NULL,
    #' @field washoutPeriod Minimum days of prior observation required.
    washoutPeriod = NULL,
    #' @field removeDuplicateSubjects How to handle persons in both arms.
    removeDuplicateSubjects = NULL,
    #' @field priorOutcomeLookback Exclude persons with outcome in this many days before index.
    priorOutcomeLookback = NULL,
    #' @field requireTimeAtRisk Require at least minDaysAtRisk days in the risk window.
    requireTimeAtRisk = NULL,
    #' @field minDaysAtRisk Minimum days at risk (when requireTimeAtRisk is TRUE).
    minDaysAtRisk = NULL,
    #' @field maxDaysAtRisk Maximum days at risk; outcomes after this are ignored. 99999 = no cap.
    maxDaysAtRisk = NULL,
    #' @field riskWindowStart Days from startAnchor to the start of the risk window.
    riskWindowStart = NULL,
    #' @field riskWindowEnd Days from endAnchor to the end of the risk window.
    riskWindowEnd = NULL,
    #' @field startAnchor Anchor for riskWindowStart: "cohort start" or "cohort end".
    startAnchor = NULL,
    #' @field endAnchor Anchor for riskWindowEnd: "cohort start" or "cohort end".
    endAnchor = NULL,
    #' @field censorAtNewRiskWindow Censor subjects when they start a new risk window.
    censorAtNewRiskWindow = NULL,

    #' @description Construct from named arguments or a JSON string.
    #' @param outcomeId,firstExposureOnly,washoutPeriod,removeDuplicateSubjects See factory.
    #' @param priorOutcomeLookback,requireTimeAtRisk,minDaysAtRisk,maxDaysAtRisk See factory.
    #' @param riskWindowStart,riskWindowEnd,startAnchor,endAnchor,censorAtNewRiskWindow See factory.
    #' @param json JSON string from `toJson()`. When supplied, all other arguments are ignored.
    initialize = function(outcomeId = NULL,
                          firstExposureOnly = FALSE,
                          washoutPeriod = 0L,
                          removeDuplicateSubjects = "keep all",
                          priorOutcomeLookback = 0L,
                          requireTimeAtRisk = TRUE,
                          minDaysAtRisk = 1L,
                          maxDaysAtRisk = 99999L,
                          riskWindowStart = 0L,
                          riskWindowEnd = 0L,
                          startAnchor = "cohort start",
                          endAnchor = "cohort end",
                          censorAtNewRiskWindow = FALSE,
                          json = NULL) {
      self$outcomeId <- outcomeId
      self$firstExposureOnly <- firstExposureOnly
      self$washoutPeriod <- as.integer(washoutPeriod)
      self$removeDuplicateSubjects <- removeDuplicateSubjects
      self$priorOutcomeLookback <- as.integer(priorOutcomeLookback)
      self$requireTimeAtRisk <- requireTimeAtRisk
      self$minDaysAtRisk <- as.integer(minDaysAtRisk)
      self$maxDaysAtRisk <- as.integer(maxDaysAtRisk)
      self$riskWindowStart <- as.integer(riskWindowStart)
      self$riskWindowEnd <- as.integer(riskWindowEnd)
      self$startAnchor <- startAnchor
      self$endAnchor <- endAnchor
      self$censorAtNewRiskWindow <- censorAtNewRiskWindow
      if (!is.null(json)) {
        super$initialize(json = json)
      }
    },

    #' @description Validate all fields using checkmate.
    validate = function() {
      errorMessages <- checkmate::makeAssertCollection()
      checkmate::assertInt(self$outcomeId, lower = 1L, add = errorMessages)
      checkmate::assertLogical(self$firstExposureOnly, len = 1L, add = errorMessages)
      checkmate::assertInt(self$washoutPeriod, lower = 0L, add = errorMessages)
      checkmate::assertChoice(
        self$removeDuplicateSubjects,
        c("keep all", "keep first", "remove all"),
        add = errorMessages
      )
      checkmate::assertInt(self$priorOutcomeLookback, lower = 0L, add = errorMessages)
      checkmate::assertLogical(self$requireTimeAtRisk, len = 1L, add = errorMessages)
      checkmate::assertInt(self$minDaysAtRisk, lower = 0L, add = errorMessages)
      checkmate::assertInt(self$maxDaysAtRisk, lower = 1L, add = errorMessages)
      checkmate::assertInt(self$riskWindowStart, add = errorMessages)
      checkmate::assertInt(self$riskWindowEnd, add = errorMessages)
      checkmate::assertChoice(self$startAnchor, c("cohort start", "cohort end"), add = errorMessages)
      checkmate::assertChoice(self$endAnchor, c("cohort start", "cohort end"), add = errorMessages)
      checkmate::assertLogical(self$censorAtNewRiskWindow, len = 1L, add = errorMessages)
      checkmate::reportAssertions(collection = errorMessages)
      invisible(self)
    }
  )
)

# ---- Factory ----------------------------------------------------------------

#' Create study population arguments
#'
#' @description
#' Specifies the outcome and inclusion/exclusion criteria for
#' [createStudyPopulation()].
#'
#' @param outcomeId (`integer(1)`) Cohort ID of the outcome of interest.
#' @param firstExposureOnly (`logical(1)`) If `TRUE`, keep only the earliest
#'   cohort entry per person per treatment arm. Default: `FALSE`.
#' @param washoutPeriod (`integer(1)`) Minimum days of prior observation
#'   required. Applied only when the `cohorts` table includes
#'   `observation_period_start_date`; silently skipped otherwise.
#'   Default: `0`.
#' @param removeDuplicateSubjects (`character(1)`) How to handle persons who
#'   appear in both the switcher and comparator arms: `"keep all"` (default),
#'   `"keep first"` (one row per person, earliest index date), or
#'   `"remove all"` (exclude all such persons).
#' @param priorOutcomeLookback (`integer(1)`) Exclude persons who had the
#'   outcome within this many days before their index date. `0` means no
#'   exclusion. Default: `0`.
#' @param requireTimeAtRisk (`logical(1)`) If `TRUE`, exclude persons who have
#'   fewer than `minDaysAtRisk` days in their risk window. Default: `TRUE`.
#' @param minDaysAtRisk (`integer(1)`) Minimum days at risk required when
#'   `requireTimeAtRisk` is `TRUE`. Default: `1`.
#' @param maxDaysAtRisk (`integer(1)`) Cap the follow-up at this many days.
#'   Outcomes occurring after the cap are not counted. `99999` means no cap.
#'   Default: `99999`.
#' @param riskWindowStart (`integer(1)`) Days from `startAnchor` to the start
#'   of the risk window. Default: `0`.
#' @param riskWindowEnd (`integer(1)`) Days from `endAnchor` to the end of
#'   the risk window. Default: `0`.
#' @param startAnchor (`character(1)`) The date to which `riskWindowStart` is
#'   added: `"cohort start"` (index date) or `"cohort end"`. Default:
#'   `"cohort start"`.
#' @param endAnchor (`character(1)`) The date to which `riskWindowEnd` is
#'   added: `"cohort start"` (index date) or `"cohort end"`. Default:
#'   `"cohort end"`.
#' @param censorAtNewRiskWindow (`logical(1)`) Reserved for future use.
#'   Default: `FALSE`.
#'
#' @return A `StudyPopulationArgs` R6 object.
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' args <- createStudyPopulationArgs(
#'   outcomeId = 3L,
#'   requireTimeAtRisk = TRUE,
#'   minDaysAtRisk = 1L,
#'   riskWindowStart = 0L,
#'   riskWindowEnd = 365L,
#'   endAnchor = "cohort start"
#' )
#'
#' @export
createStudyPopulationArgs <- function(outcomeId,
                                      firstExposureOnly = FALSE,
                                      washoutPeriod = 0L,
                                      removeDuplicateSubjects = "keep all",
                                      priorOutcomeLookback = 0L,
                                      requireTimeAtRisk = TRUE,
                                      minDaysAtRisk = 1L,
                                      maxDaysAtRisk = 99999L,
                                      riskWindowStart = 0L,
                                      riskWindowEnd = 0L,
                                      startAnchor = "cohort start",
                                      endAnchor = "cohort end",
                                      censorAtNewRiskWindow = FALSE) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertInt(outcomeId, lower = 1L, add = errorMessages)
  checkmate::assertLogical(firstExposureOnly, len = 1L, add = errorMessages)
  checkmate::assertInt(washoutPeriod, lower = 0L, add = errorMessages)
  checkmate::assertChoice(
    removeDuplicateSubjects,
    c("keep all", "keep first", "remove all"),
    add = errorMessages
  )
  checkmate::assertInt(priorOutcomeLookback, lower = 0L, add = errorMessages)
  checkmate::assertLogical(requireTimeAtRisk, len = 1L, add = errorMessages)
  checkmate::assertInt(minDaysAtRisk, lower = 0L, add = errorMessages)
  checkmate::assertInt(maxDaysAtRisk, lower = 1L, add = errorMessages)
  checkmate::assertInt(riskWindowStart, add = errorMessages)
  checkmate::assertInt(riskWindowEnd, add = errorMessages)
  checkmate::assertChoice(startAnchor, c("cohort start", "cohort end"), add = errorMessages)
  checkmate::assertChoice(endAnchor, c("cohort start", "cohort end"), add = errorMessages)
  checkmate::assertLogical(censorAtNewRiskWindow, len = 1L, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  StudyPopulationArgs$new(
    outcomeId = as.integer(outcomeId),
    firstExposureOnly = firstExposureOnly,
    washoutPeriod = as.integer(washoutPeriod),
    removeDuplicateSubjects = removeDuplicateSubjects,
    priorOutcomeLookback = as.integer(priorOutcomeLookback),
    requireTimeAtRisk = requireTimeAtRisk,
    minDaysAtRisk = as.integer(minDaysAtRisk),
    maxDaysAtRisk = as.integer(maxDaysAtRisk),
    riskWindowStart = as.integer(riskWindowStart),
    riskWindowEnd = as.integer(riskWindowEnd),
    startAnchor = startAnchor,
    endAnchor = endAnchor,
    censorAtNewRiskWindow = censorAtNewRiskWindow
  )
}

# ---- createStudyPopulation --------------------------------------------------

#' Create a study population from a PnuData object
#'
#' @description
#' Filters the cohort data in `pnuData` for a specific outcome and applies
#' inclusion/exclusion criteria specified in `studyPopulationArgs`. The
#' resulting `studyPopulation` table is written into `pnuData` (Andromeda is a
#' reference object, so the original is modified in place) and the same object
#' is returned.
#'
#' The `studyPopulation` table adds `survival_time`, `outcome_count`, and
#' `days_to_event` columns to the cohort rows. These are used by all
#' downstream steps (TCPS, matching, outcome models).
#'
#' @details
#' **Risk window** The at-risk period for each person runs from
#' `startAnchor + riskWindowStart` to
#' `min(endAnchor + riskWindowEnd, cohort_end_date)`.
#' `survival_time` is the number of days from the risk window start to the
#' first outcome or the end of follow-up, whichever comes first.
#'
#' **washoutPeriod** Applied only when the `cohorts` table contains an
#' `observation_period_start_date` column. In simulated data (from
#' [simulatePnuData()]) that column is absent; a `washoutPeriod > 0` is
#' silently skipped with a message.
#'
#' **censorAtNewRiskWindow** Stored in `studyPopulationArgs` but not yet
#' implemented; a warning is issued when set to `TRUE`.
#'
#' @param pnuData A [PnuData] object from [getDbPnuData()] or
#'   [simulatePnuData()].
#' @param studyPopulationArgs A `StudyPopulationArgs` object from
#'   [createStudyPopulationArgs()].
#'
#' @return The same `pnuData` object with `pnuData$studyPopulation` populated.
#'   The returned object is the same reference as the input; the caller does not
#'   need to capture the return value.
#'
#' @seealso [createStudyPopulationArgs()], [simulatePnuData()], [getDbPnuData()]
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' \dontrun{
#' simArgs <- createSimulationArgs(nSwitchers = 200L, seed = 1L)
#' pnuData <- simulatePnuData(simArgs)
#' spArgs <- createStudyPopulationArgs(outcomeId = 1L)
#' pnuData <- createStudyPopulation(pnuData, spArgs)
#' sp <- dplyr::collect(pnuData$studyPopulation)
#' Andromeda::close(pnuData)
#' }
#'
#' @export
createStudyPopulation <- function(pnuData, studyPopulationArgs) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertClass(pnuData, "PnuData", add = errorMessages)
  checkmate::assertClass(studyPopulationArgs, "StudyPopulationArgs", add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  if (isTRUE(studyPopulationArgs$censorAtNewRiskWindow)) {
    warning("censorAtNewRiskWindow = TRUE is not yet implemented; ignored.")
  }

  args <- studyPopulationArgs

  cohorts <- dplyr::collect(pnuData$cohorts)
  outcomes <- dplyr::collect(pnuData$outcomes) |>
    dplyr::filter(.data$outcome_id == args$outcomeId)

  # firstExposureOnly: keep earliest index date per person per arm
  if (args$firstExposureOnly) {
    cohorts <- cohorts |>
      dplyr::arrange(.data$cohort_start_date) |>
      dplyr::group_by(.data$person_id, .data$treatment) |>
      dplyr::slice(1L) |>
      dplyr::ungroup()
  }

  # removeDuplicateSubjects
  rds <- args$removeDuplicateSubjects
  if (rds == "keep first") {
    cohorts <- cohorts |>
      dplyr::arrange(.data$cohort_start_date) |>
      dplyr::group_by(.data$person_id) |>
      dplyr::slice(1L) |>
      dplyr::ungroup()
  } else if (rds == "remove all") {
    dup_ids <- cohorts |>
      dplyr::group_by(.data$person_id) |>
      dplyr::summarise(n_arms = dplyr::n_distinct(.data$treatment), .groups = "drop") |>
      dplyr::filter(.data$n_arms > 1L) |>
      dplyr::pull(.data$person_id)
    cohorts <- dplyr::filter(cohorts, !(.data$person_id %in% dup_ids))
  }

  # washoutPeriod: skip silently if observation_period_start_date absent
  if (args$washoutPeriod > 0L) {
    if ("observation_period_start_date" %in% names(cohorts)) {
      cohorts <- dplyr::filter(
        cohorts,
        as.integer(.data$cohort_start_date - .data$observation_period_start_date) >=
          args$washoutPeriod
      )
    } else {
      message(
        "washoutPeriod > 0 but cohorts table has no observation_period_start_date column; ",
        "washout check skipped."
      )
    }
  }

  # priorOutcomeLookback: exclude persons with outcome before index date
  if (args$priorOutcomeLookback > 0L) {
    prior_events <- dplyr::inner_join(
      dplyr::select(cohorts, "person_seq_id", "cohort_start_date"),
      outcomes,
      by = "person_seq_id"
    ) |>
      dplyr::filter(
        .data$outcome_date >= .data$cohort_start_date - args$priorOutcomeLookback,
        .data$outcome_date < .data$cohort_start_date
      ) |>
      dplyr::distinct(.data$person_seq_id)
    cohorts <- dplyr::filter(cohorts, !(.data$person_seq_id %in% prior_events$person_seq_id))
  }

  # Risk window dates
  if (args$startAnchor == "cohort start") {
    cohorts$risk_start <- cohorts$cohort_start_date + args$riskWindowStart
  } else {
    cohorts$risk_start <- cohorts$cohort_end_date + args$riskWindowStart
  }
  if (args$endAnchor == "cohort start") {
    cohorts$risk_end <- cohorts$cohort_start_date + args$riskWindowEnd
  } else {
    cohorts$risk_end <- cohorts$cohort_end_date + args$riskWindowEnd
  }
  cohorts$follow_end <- pmin(cohorts$risk_end, cohorts$cohort_end_date)
  cohorts$time_at_risk <- pmax(0L, as.integer(cohorts$follow_end - cohorts$risk_start))

  # First outcome in risk window per person
  in_window <- dplyr::inner_join(
    dplyr::select(cohorts, "person_seq_id", "risk_start", "follow_end"),
    outcomes,
    by = "person_seq_id"
  ) |>
    dplyr::filter(
      .data$outcome_date >= .data$risk_start,
      .data$outcome_date <= .data$follow_end
    ) |>
    dplyr::arrange(.data$outcome_date) |>
    dplyr::group_by(.data$person_seq_id) |>
    dplyr::slice(1L) |>
    dplyr::ungroup() |>
    dplyr::select("person_seq_id", "outcome_date")

  pop <- dplyr::left_join(cohorts, in_window, by = "person_seq_id") |>
    dplyr::mutate(
      outcome_count = as.integer(!is.na(.data$outcome_date)),
      days_to_event = dplyr::if_else(
        .data$outcome_count == 1L,
        as.integer(.data$outcome_date - .data$risk_start),
        NA_integer_
      ),
      survival_time = dplyr::if_else(
        .data$outcome_count == 1L,
        .data$days_to_event,
        .data$time_at_risk
      )
    )

  # maxDaysAtRisk: cap follow-up; outcomes after the cap are not counted
  max_days <- as.integer(args$maxDaysAtRisk)
  if (!is.na(max_days) && max_days < 99999L) {
    pop <- pop |>
      dplyr::mutate(
        outcome_count = dplyr::if_else(
          !is.na(.data$days_to_event) & .data$days_to_event > max_days,
          0L, .data$outcome_count
        ),
        days_to_event = dplyr::if_else(
          .data$outcome_count == 0L, NA_integer_, .data$days_to_event
        ),
        survival_time = pmin(.data$survival_time, max_days)
      )
  }

  # requireTimeAtRisk: drop persons with too few days
  if (args$requireTimeAtRisk) {
    pop <- dplyr::filter(pop, .data$time_at_risk >= args$minDaysAtRisk)
  }

  studyPop <- dplyr::select(
    pop,
    "row_id", "person_seq_id", "person_id",
    "cohort_start_date", "cohort_end_date",
    "treatment", "exposure_set_id",
    "survival_time", "outcome_count", "days_to_event"
  )

  pnuData$studyPopulation <- studyPop
  pnuData
}
