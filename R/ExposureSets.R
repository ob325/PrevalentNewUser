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

# ---- Internal helpers ----------------------------------------------------

# Total days a person spent on treatment A strictly before `beforeDate`.
# A eras that start on or after `beforeDate` are ignored; eras that extend
# past `beforeDate` are truncated.
.daysOnABeforeDate <- function(aEras, beforeDate) {
  if (nrow(aEras) == 0L) return(0L)
  aEras <- aEras[aEras$cohort_start_date < beforeDate, , drop = FALSE]
  if (nrow(aEras) == 0L) return(0L)
  effectiveEnd <- pmin(aEras$cohort_end_date, beforeDate - 1L)
  as.integer(sum(as.integer(effectiveEnd - aEras$cohort_start_date + 1L)))
}

# Number of treatment-A eras that started strictly before `beforeDate`.
.fillsOnABeforeDate <- function(aEras, beforeDate) {
  as.integer(sum(aEras$cohort_start_date < beforeDate))
}

# Date on which cumulative days on A first equals `targetDays`.
# Returns NA if the person's A history is too short.
.findDateForDaysOnA <- function(aEras, targetDays) {
  if (targetDays == 0L) return(as.Date(NA))
  aEras <- aEras[order(aEras$cohort_start_date), , drop = FALSE]
  cumDays <- 0L
  for (i in seq_len(nrow(aEras))) {
    eraLen <- as.integer(aEras$cohort_end_date[i] - aEras$cohort_start_date[i] + 1L)
    if (cumDays + eraLen >= targetDays) {
      return(aEras$cohort_start_date[i] + (targetDays - cumDays))
    }
    cumDays <- cumDays + eraLen
  }
  as.Date(NA)
}

# Date on which the `targetFills`-th treatment-A era begins.
# Returns NA if the person has fewer than `targetFills` eras.
.findDateForFillCount <- function(aEras, targetFills) {
  if (targetFills == 0L) return(as.Date(NA))
  aEras <- aEras[order(aEras$cohort_start_date), , drop = FALSE]
  if (nrow(aEras) < targetFills) return(as.Date(NA))
  aEras$cohort_start_date[targetFills]
}

# ---- Reference implementation --------------------------------------------

#' Compute exposure sets in pure R (reference implementation)
#'
#' @description
#' Assigns every switcher and every eligible comparator to one or more
#' exposure sets, returning a single data frame that the SQL implementation
#' (Step 2.2) must reproduce exactly on the same input.
#'
#' **Switchers** are all persons present in `treatmentB`. Their exposure set
#' is determined by their history of treatment A on the day they started B.
#'
#' **Comparators** are persons present in `treatmentA` who are *not* switchers.
#' For each exposure set E that exists among the switchers, a comparator is
#' eligible if and only if:
#' 1. They reached exposure-set E in their own A history (i.e. a candidate
#'    index date exists), AND
#' 2. They were still on treatment A on that candidate index date, AND
#' 3. They were within their observation period on that date.
#'
#' A comparator can appear in multiple rows (one per exposure set they are
#' eligible for). Exposure set 0 (no prior A) is supported for **switchers**
#' only; comparator identification for set 0 requires calendar-date matching
#' that is handled in the study-population step.
#'
#' @param treatmentA Data frame — treatment A (reference) cohort. Required
#'   columns: `subject_id`, `cohort_start_date`, `cohort_end_date`.
#' @param treatmentB Data frame — treatment B (switcher) cohort. Required
#'   columns: `subject_id`, `cohort_start_date`.
#' @param observationPeriod Data frame — OMOP observation_period. Required
#'   columns: `person_id`, `observation_period_start_date`,
#'   `observation_period_end_date`.
#' @param exposureSetDefinition `"time"` (days on A) or `"fills"` (number of
#'   A eras started before the switch). Default: `"time"`.
#'
#' @return A data frame with one row per (person, exposure-set) pair:
#'   \describe{
#'     \item{`person_id`}{Character person identifier.}
#'     \item{`exposure_set`}{Integer exposure-set identifier (0 = no prior A).}
#'     \item{`index_date`}{Date index date for this row.}
#'     \item{`is_switcher`}{Logical — `TRUE` for switchers, `FALSE` for comparators.}
#'   }
#'
#' @keywords internal
computeExposureSetsInR <- function(treatmentA,
                                   treatmentB,
                                   observationPeriod,
                                   exposureSetDefinition = "time") {
  checkmate::assertDataFrame(treatmentA,
    min.rows = 0,
    col.names = "named"
  )
  checkmate::assertDataFrame(treatmentB,
    min.rows = 0,
    col.names = "named"
  )
  checkmate::assertDataFrame(observationPeriod,
    min.rows = 0,
    col.names = "named"
  )
  checkmate::assertChoice(exposureSetDefinition, c("time", "fills"))
  checkmate::assertNames(names(treatmentA),
    must.include = c("subject_id", "cohort_start_date", "cohort_end_date")
  )
  checkmate::assertNames(names(treatmentB),
    must.include = c("subject_id", "cohort_start_date")
  )
  checkmate::assertNames(names(observationPeriod),
    must.include = c(
      "person_id",
      "observation_period_start_date",
      "observation_period_end_date"
    )
  )

  switcherIds <- unique(treatmentB$subject_id)

  # ---- Switcher rows -------------------------------------------------------
  switcherRows <- lapply(switcherIds, function(pid) {
    bEras <- treatmentB[treatmentB$subject_id == pid, , drop = FALSE]
    aEras <- treatmentA[treatmentA$subject_id == pid, , drop = FALSE]
    bStart <- min(bEras$cohort_start_date)

    exposureSet <- if (exposureSetDefinition == "time") {
      .daysOnABeforeDate(aEras, bStart)
    } else {
      .fillsOnABeforeDate(aEras, bStart)
    }

    data.frame(
      person_id = as.character(pid),
      exposure_set = as.integer(exposureSet),
      index_date = bStart,
      is_switcher = TRUE,
      stringsAsFactors = FALSE
    )
  })
  if (length(switcherRows) == 0L) {
    return(data.frame(
      person_id = character(0),
      exposure_set = integer(0),
      index_date = as.Date(character(0)),
      is_switcher = logical(0),
      stringsAsFactors = FALSE
    ))
  }
  switcherData <- do.call(rbind, switcherRows)
  rownames(switcherData) <- NULL

  # ---- Comparator rows -----------------------------------------------------
  # Only sets > 0 are handled here; set 0 comparators require calendar matching.
  uniqueSets <- sort(unique(switcherData$exposure_set[switcherData$exposure_set > 0L]))
  comparatorIds <- setdiff(treatmentA$subject_id, switcherIds)

  comparatorRows <- list()
  for (pid in comparatorIds) {
    aEras <- treatmentA[treatmentA$subject_id == pid, , drop = FALSE]
    aEras <- aEras[order(aEras$cohort_start_date), , drop = FALSE]

    obs <- observationPeriod[observationPeriod$person_id == pid, , drop = FALSE]

    for (E in uniqueSets) {
      indexDate <- if (exposureSetDefinition == "time") {
        .findDateForDaysOnA(aEras, E)
      } else {
        .findDateForFillCount(aEras, E)
      }

      if (is.na(indexDate)) next

      # Must still be on treatment A at index date
      onA <- any(
        aEras$cohort_start_date <= indexDate &
          aEras$cohort_end_date >= indexDate
      )
      if (!onA) next

      # Must be within observation period
      if (nrow(obs) == 0L) next
      inObs <- any(
        obs$observation_period_start_date <= indexDate &
          obs$observation_period_end_date >= indexDate
      )
      if (!inObs) next

      comparatorRows[[length(comparatorRows) + 1L]] <- data.frame(
        person_id = as.character(pid),
        exposure_set = as.integer(E),
        index_date = indexDate,
        is_switcher = FALSE,
        stringsAsFactors = FALSE
      )
    }
  }

  comparatorData <- if (length(comparatorRows) == 0L) {
    NULL
  } else {
    d <- do.call(rbind, comparatorRows)
    rownames(d) <- NULL
    d
  }

  result <- rbind(switcherData, comparatorData)
  result[order(result$person_id, result$exposure_set), ]
}

# ---- Database implementation ---------------------------------------------

#' Compute exposure sets on a database server
#'
#' @description
#' Executes `GetExposureSets.sql` against a database cohort table and returns
#' the result as a tibble. The output schema matches [computeExposureSetsInR()].
#'
#' Observation-period eligibility is **not** checked here; that filter is
#' applied in [createStudyPopulation()].
#'
#' @param connection A `DatabaseConnector` connection object.
#' @param cohortDatabaseSchema Schema name that contains `cohortTable`.
#' @param cohortTable Name of the cohort table (without schema prefix).
#' @param targetCohortId (`integer(1)`) Cohort ID for treatment A.
#' @param comparatorCohortId (`integer(1)`) Cohort ID for treatment B (switchers).
#' @param tempEmulationSchema Schema for temp-table emulation on databases that
#'   do not support native temp tables (e.g. Oracle, BigQuery). Pass `NULL`
#'   on supported databases.
#' @param exposureSetDefinition `"time"` (days on A) or `"fills"` (A era count).
#'   Default: `"time"`.
#'
#' @return A [dplyr::tibble()] with columns `person_id` (character),
#'   `exposure_set` (integer), `index_date` (Date), `is_switcher` (logical).
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' \dontrun{
#' connectionDetails <- DatabaseConnector::createConnectionDetails(
#'   dbms = "sqlite",
#'   server = ":memory:"
#' )
#' conn <- DatabaseConnector::connect(connectionDetails)
#' es <- getDbExposureSets(
#'   connection = conn,
#'   cohortDatabaseSchema = "main",
#'   cohortTable = "cohort",
#'   targetCohortId = 1L,
#'   comparatorCohortId = 2L
#' )
#' DatabaseConnector::disconnect(conn)
#' }
#'
#' @export
getDbExposureSets <- function(connection,
                               cohortDatabaseSchema,
                               cohortTable,
                               targetCohortId,
                               comparatorCohortId,
                               tempEmulationSchema = NULL,
                               exposureSetDefinition = "time") {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertClass(connection, "DatabaseConnectorConnection", add = errorMessages)
  checkmate::assertCharacter(cohortDatabaseSchema, len = 1, add = errorMessages)
  checkmate::assertCharacter(cohortTable, len = 1, add = errorMessages)
  checkmate::assertInt(targetCohortId, lower = 1, add = errorMessages)
  checkmate::assertInt(comparatorCohortId, lower = 1, add = errorMessages)
  checkmate::assertCharacter(tempEmulationSchema, len = 1, null.ok = TRUE, add = errorMessages)
  checkmate::assertChoice(exposureSetDefinition, c("time", "fills"), add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  ParallelLogger::logInfo("Computing exposure sets on database")

  on.exit(
    SqlRender::loadRenderTranslateSql(
      sqlFilename = "DropExposureSets.sql",
      packageName = "PrevalentNewUser",
      dbms = connection@dbms,
      tempEmulationSchema = tempEmulationSchema
    ) |>
      DatabaseConnector::executeSql(connection = connection, progressBar = FALSE,
                                    reportOverallTime = FALSE),
    add = TRUE
  )

  sql <- SqlRender::loadRenderTranslateSql(
    sqlFilename = "GetExposureSets.sql",
    packageName = "PrevalentNewUser",
    dbms = connection@dbms,
    tempEmulationSchema = tempEmulationSchema,
    cohort_database_schema = cohortDatabaseSchema,
    cohort_table = cohortTable,
    target_cohort_id = targetCohortId,
    comparator_cohort_id = comparatorCohortId,
    exposure_set_definition = exposureSetDefinition
  )
  DatabaseConnector::executeSql(connection, sql, progressBar = FALSE,
                                reportOverallTime = FALSE)

  result <- DatabaseConnector::querySql(
    connection,
    sql = SqlRender::translate(
      "SELECT person_id, exposure_set, index_date, is_switcher
       FROM #exposure_sets
       ORDER BY person_id, exposure_set;",
      targetDialect = connection@dbms,
      tempEmulationSchema = tempEmulationSchema
    ),
    snakeCaseToCamelCase = FALSE
  )

  # Normalise column names (DB returns upper-case) and coerce types
  dplyr::tibble(
    person_id    = as.character(result$PERSON_ID),
    exposure_set = as.integer(result$EXPOSURE_SET),
    index_date   = as.Date(result$INDEX_DATE),
    is_switcher  = as.logical(result$IS_SWITCHER)
  )
}
