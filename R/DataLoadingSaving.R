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

# ---- Internal helpers -------------------------------------------------------

.dropTempTable <- function(connection, tableName, tempEmulationSchema = NULL) {
  sql <- SqlRender::translate(
    paste0("DROP TABLE IF EXISTS ", tableName, ";"),
    targetDialect       = connection@dbms,
    tempEmulationSchema = tempEmulationSchema
  )
  try(
    DatabaseConnector::executeSql(
      connection,
      sql,
      progressBar     = FALSE,
      reportOverallTime = FALSE
    ),
    silent = TRUE
  )
  invisible(NULL)
}

# ---- getDbPnuData -----------------------------------------------------------

#' Load prevalent new-user study data from a database
#'
#' @description
#' Executes the exposure-set and cohort SQL against the CDM, calls
#' FeatureExtraction to collect covariates, queries the outcome cohort, and
#' returns a [PnuData] object containing all tables needed for downstream
#' analysis.
#'
#' @param connection A `DatabaseConnector` connection object.
#' @param cdmDatabaseSchema Schema containing the OMOP CDM tables.
#' @param cohortDatabaseSchema Schema containing `cohortTable`.
#' @param cohortTable Name of the cohort table (without schema prefix).
#' @param pnuCohortArgs A [PnuCohortArgs] settings object created by
#'   [createPnuCohortArgs()].
#' @param covariateSettings A covariate settings object created by
#'   `FeatureExtraction::createCovariateSettings()` or similar.
#' @param tempEmulationSchema Schema for temp-table emulation on databases that
#'   do not support native temp tables. Pass `NULL` on supported databases.
#' @param exposureSetDefinition `"time"` (days on treatment A) or `"fills"`
#'   (number of treatment-A eras). Default: `"time"`.
#' @param restrictToCommonPeriod Not yet implemented; reserved for future use.
#'
#' @return A [PnuData] object.
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' \dontrun{
#' connectionDetails <- DatabaseConnector::createConnectionDetails(
#'   dbms = "sqlite", server = ":memory:"
#' )
#' conn <- DatabaseConnector::connect(connectionDetails)
#' pnuData <- getDbPnuData(
#'   connection           = conn,
#'   cdmDatabaseSchema    = "main",
#'   cohortDatabaseSchema = "main",
#'   cohortTable          = "cohort",
#'   pnuCohortArgs        = createPnuCohortArgs(
#'     targetCohortId = 1L, comparatorCohortId = 2L, outcomeCohortId = 3L
#'   ),
#'   covariateSettings    = FeatureExtraction::createDefaultCovariateSettings()
#' )
#' DatabaseConnector::disconnect(conn)
#' }
#'
#' @export
getDbPnuData <- function(connection,
                         cdmDatabaseSchema,
                         cohortDatabaseSchema,
                         cohortTable,
                         pnuCohortArgs,
                         covariateSettings,
                         tempEmulationSchema     = NULL,
                         exposureSetDefinition   = "time",
                         restrictToCommonPeriod  = FALSE) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertClass(connection, "DatabaseConnectorConnection", add = errorMessages)
  checkmate::assertCharacter(cdmDatabaseSchema,    len = 1, add = errorMessages)
  checkmate::assertCharacter(cohortDatabaseSchema, len = 1, add = errorMessages)
  checkmate::assertCharacter(cohortTable,          len = 1, add = errorMessages)
  checkmate::assertClass(pnuCohortArgs, "PnuCohortArgs", add = errorMessages)
  checkmate::assertCharacter(tempEmulationSchema, len = 1, null.ok = TRUE, add = errorMessages)
  checkmate::assertChoice(exposureSetDefinition, c("time", "fills"), add = errorMessages)
  checkmate::assertLogical(restrictToCommonPeriod, len = 1, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  targetCohortId     <- pnuCohortArgs$targetCohortId
  comparatorCohortId <- pnuCohortArgs$comparatorCohortId
  outcomeCohortId    <- pnuCohortArgs$outcomeCohortId

  ParallelLogger::logInfo("Loading PNU data from database")

  # Clean up temp tables even if an error occurs
  on.exit({
    .dropTempTable(connection, "#exposure_sets", tempEmulationSchema)
    .dropTempTable(connection, "#pnu_cohorts",   tempEmulationSchema)
  }, add = TRUE)

  # Step 1 — Exposure sets → #exposure_sets
  ParallelLogger::logInfo("Computing exposure sets")
  sql <- SqlRender::loadRenderTranslateSql(
    sqlFilename            = "GetExposureSets.sql",
    packageName            = "PrevalentNewUser",
    dbms                   = connection@dbms,
    tempEmulationSchema    = tempEmulationSchema,
    cohort_database_schema = cohortDatabaseSchema,
    cohort_table           = cohortTable,
    target_cohort_id       = targetCohortId,
    comparator_cohort_id   = comparatorCohortId,
    exposure_set_definition = exposureSetDefinition
  )
  DatabaseConnector::executeSql(connection, sql,
    progressBar = FALSE, reportOverallTime = FALSE)

  # Step 2 — Cohort table → #pnu_cohorts
  ParallelLogger::logInfo("Building cohort table")
  sql <- SqlRender::loadRenderTranslateSql(
    sqlFilename            = "GetCohorts.sql",
    packageName            = "PrevalentNewUser",
    dbms                   = connection@dbms,
    tempEmulationSchema    = tempEmulationSchema,
    cohort_database_schema = cohortDatabaseSchema,
    cohort_table           = cohortTable,
    target_cohort_id       = targetCohortId,
    comparator_cohort_id   = comparatorCohortId
  )
  DatabaseConnector::executeSql(connection, sql,
    progressBar = FALSE, reportOverallTime = FALSE)

  # Step 3 — Pull cohort rows into R
  ParallelLogger::logInfo("Pulling cohort data")
  cohortRaw <- DatabaseConnector::querySql(
    connection,
    sql = SqlRender::translate(
      "SELECT row_id, person_seq_id, person_id,
              cohort_start_date, cohort_end_date,
              treatment, exposure_set_id
       FROM #pnu_cohorts
       ORDER BY row_id;",
      targetDialect       = connection@dbms,
      tempEmulationSchema = tempEmulationSchema
    ),
    snakeCaseToCamelCase = FALSE
  )

  cohortTbl <- dplyr::tibble(
    row_id            = as.integer(cohortRaw$ROW_ID),
    person_seq_id     = as.integer(cohortRaw$PERSON_SEQ_ID),
    person_id         = as.character(cohortRaw$PERSON_ID),
    cohort_start_date = as.Date(cohortRaw$COHORT_START_DATE),
    cohort_end_date   = as.Date(cohortRaw$COHORT_END_DATE),
    treatment         = as.integer(cohortRaw$TREATMENT),
    exposure_set_id   = as.integer(cohortRaw$EXPOSURE_SET_ID)
  )

  # Step 4 — Pull outcomes
  ParallelLogger::logInfo("Pulling outcomes")
  outcomeSql <- SqlRender::translate(
    SqlRender::render(
      paste(
        "SELECT DISTINCT c.person_seq_id,",
        "  @outcome_cohort_id AS outcome_id,",
        "  oc.cohort_start_date AS outcome_date",
        "FROM #pnu_cohorts c",
        "INNER JOIN @cohort_database_schema.@cohort_table oc",
        "  ON  oc.subject_id           = c.subject_id",
        "  AND oc.cohort_definition_id = @outcome_cohort_id",
        "  AND oc.cohort_start_date   >= c.cohort_start_date",
        "ORDER BY c.person_seq_id, oc.cohort_start_date;"
      ),
      outcome_cohort_id      = outcomeCohortId,
      cohort_database_schema = cohortDatabaseSchema,
      cohort_table           = cohortTable
    ),
    targetDialect       = connection@dbms,
    tempEmulationSchema = tempEmulationSchema
  )
  outcomeRaw <- DatabaseConnector::querySql(
    connection, outcomeSql, snakeCaseToCamelCase = FALSE
  )
  outcomeTbl <- dplyr::tibble(
    person_seq_id = as.integer(outcomeRaw$PERSON_SEQ_ID),
    outcome_id    = as.integer(outcomeRaw$OUTCOME_ID),
    outcome_date  = as.Date(outcomeRaw$OUTCOME_DATE)
  )

  # Step 5 — Derive exposureSets summary
  exposureSetsTbl <- cohortTbl |>
    dplyr::distinct(.data$person_seq_id, .data$exposure_set_id) |>
    dplyr::mutate(days_on_a = .data$exposure_set_id)

  # Step 6 — Covariates via FeatureExtraction
  ParallelLogger::logInfo("Getting covariates")
  covData <- FeatureExtraction::getDbCovariateData(
    connection          = connection,
    cdmDatabaseSchema   = cdmDatabaseSchema,
    cohortTable         = "#pnu_cohorts",
    cohortTableIsTemp   = TRUE,
    cohortId            = -1L,
    rowIdField          = "row_id",
    covariateSettings   = covariateSettings,
    tempEmulationSchema = tempEmulationSchema
  )
  on.exit(try(Andromeda::close(covData), silent = TRUE), add = TRUE)

  # Step 7 — Assemble PnuData
  metaData <- list(
    targetCohortId       = targetCohortId,
    comparatorCohortId   = comparatorCohortId,
    outcomeCohortId      = outcomeCohortId,
    cdmDatabaseSchema    = cdmDatabaseSchema,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTable          = cohortTable
  )
  pnuData <- createEmptyPnuData(metaData = metaData)

  pnuData$cohorts      <- cohortTbl
  pnuData$outcomes     <- outcomeTbl
  pnuData$exposureSets <- exposureSetsTbl
  pnuData$covariates   <- dplyr::collect(covData$covariates)
  pnuData$covariateRef <- dplyr::collect(covData$covariateRef)
  pnuData$analysisRef  <- dplyr::collect(covData$analysisRef)

  pnuData
}

# ---- savePnuData / loadPnuData ----------------------------------------------

#' Save a PnuData object to disk
#'
#' @description
#' Serialises all Andromeda tables (including covariates) to a zip file.
#' R-level attributes such as `metaData` are preserved because Andromeda
#' persists them alongside the DuckDB database.
#'
#' @param pnuData A [PnuData] object.
#' @param file Path to the output zip file.
#'
#' @return `NULL` invisibly.
#'
#' @seealso [loadPnuData()]
#'
#' @examples
#' \dontrun{
#' savePnuData(pnuData, "pnuData.zip")
#' pnuData2 <- loadPnuData("pnuData.zip")
#' }
#'
#' @export
savePnuData <- function(pnuData, file) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertClass(pnuData, "PnuData", add = errorMessages)
  checkmate::assertCharacter(file, len = 1, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  Andromeda::saveAndromeda(pnuData, fileName = file)
  invisible(NULL)
}

#' Load a PnuData object from disk
#'
#' @description
#' Restores a [PnuData] object previously written by [savePnuData()].
#'
#' @param file Path to the zip file produced by [savePnuData()].
#'
#' @return A [PnuData] object.
#'
#' @seealso [savePnuData()]
#'
#' @examples
#' \dontrun{
#' pnuData <- loadPnuData("pnuData.zip")
#' }
#'
#' @export
loadPnuData <- function(file) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertCharacter(file, len = 1, add = errorMessages)
  checkmate::assertFileExists(file, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  result <- Andromeda::loadAndromeda(fileName = file)
  class(result) <- "PnuData"
  result
}
