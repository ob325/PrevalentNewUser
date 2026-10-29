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

# ---- PnuAnalysis R6 class ---------------------------------------------------

#' Analysis specification for a single PNU analysis
#'
#' @description
#' Bundles all step-specific settings for one run of the PNU pipeline.
#' Create with [createPnuAnalysisArgs()].
#'
#' @keywords internal
PnuAnalysis <- R6::R6Class(
  classname = "PnuAnalysis",
  inherit = AbstractSerializableSettings,
  cloneable = FALSE,
  public = list(
    #' @field analysisId Unique integer identifier.
    analysisId = NULL,
    #' @field description Human-readable label.
    description = NULL,
    #' @field pnuCohortArgs [PnuCohortArgs] object; `NULL` when `pnuDataList` is
    #'   supplied to [runPnuAnalyses()].
    pnuCohortArgs = NULL,
    #' @field studyPopulationArgs [StudyPopulationArgs] object.
    studyPopulationArgs = NULL,
    #' @field tcpsArgs [TcpsArgs] object; `NULL` = uniform PS (0.5).
    tcpsArgs = NULL,
    #' @field matchingArgs [MatchingArgs] object.
    matchingArgs = NULL,
    #' @field outcomeModelArgs [OutcomeModelArgs] object.
    outcomeModelArgs = NULL,
    #' @field bootstrapArgs [BootstrapArgs] object; `NULL` = skip bootstrap.
    bootstrapArgs = NULL,
    #' @field balanceArgs [BalanceArgs] object; `NULL` = skip balance.
    balanceArgs = NULL,

    #' @description Construct from named arguments or a JSON string.
    #' @param analysisId,description,pnuCohortArgs,studyPopulationArgs,tcpsArgs,matchingArgs,outcomeModelArgs,bootstrapArgs,balanceArgs See factory.
    #' @param json JSON string from `toJson()` (restores only primitive fields).
    initialize = function(analysisId = 1L,
                          description = "",
                          pnuCohortArgs = NULL,
                          studyPopulationArgs = NULL,
                          tcpsArgs = NULL,
                          matchingArgs = NULL,
                          outcomeModelArgs = NULL,
                          bootstrapArgs = NULL,
                          balanceArgs = NULL,
                          json = NULL) {
      self$analysisId <- as.integer(analysisId)
      self$description <- as.character(description)
      self$pnuCohortArgs <- pnuCohortArgs
      self$studyPopulationArgs <- studyPopulationArgs
      self$tcpsArgs <- tcpsArgs
      self$matchingArgs <- matchingArgs
      self$outcomeModelArgs <- outcomeModelArgs
      self$bootstrapArgs <- bootstrapArgs
      self$balanceArgs <- balanceArgs
      if (!is.null(json)) super$initialize(json = json)
    },

    #' @description Validate all fields using checkmate.
    validate = function() {
      errorMessages <- checkmate::makeAssertCollection()
      checkmate::assertInt(self$analysisId, lower = 1L, add = errorMessages)
      checkmate::assertString(self$description, add = errorMessages)
      if (!is.null(self$pnuCohortArgs)) {
        checkmate::assertClass(self$pnuCohortArgs, "PnuCohortArgs", add = errorMessages)
      }
      checkmate::assertClass(self$studyPopulationArgs, "StudyPopulationArgs",
        add = errorMessages
      )
      if (!is.null(self$tcpsArgs)) {
        checkmate::assertClass(self$tcpsArgs, "TcpsArgs", add = errorMessages)
      }
      checkmate::assertClass(self$matchingArgs, "MatchingArgs", add = errorMessages)
      checkmate::assertClass(self$outcomeModelArgs, "OutcomeModelArgs", add = errorMessages)
      if (!is.null(self$bootstrapArgs)) {
        checkmate::assertClass(self$bootstrapArgs, "BootstrapArgs", add = errorMessages)
      }
      if (!is.null(self$balanceArgs)) {
        checkmate::assertClass(self$balanceArgs, "BalanceArgs", add = errorMessages)
      }
      checkmate::reportAssertions(collection = errorMessages)
      invisible(self)
    },

    #' @description Serialise to JSON (primitive fields only).
    #' @details Nested settings objects contain Cyclops objects that are not
    #'   JSON-serializable; only `analysisId` and `description` are round-tripped.
    toJson = function() {
      result <- list(
        analysisId = self$analysisId,
        description = self$description
      )
      jsonlite::toJSON(result,
        pretty = TRUE, auto_unbox = TRUE, null = "null", digits = 15
      )
    }
  )
)

# ---- createPnuAnalysisArgs --------------------------------------------------

#' Create a PNU analysis specification
#'
#' @description
#' Bundles all step-specific settings for one run of the PNU pipeline.
#' Pass a list of these objects to [runPnuAnalyses()].
#'
#' @param analysisId (`integer(1)`) Unique analysis identifier. Default: `1`.
#' @param description (`character(1)`) Human-readable label. Default: `""`.
#' @param pnuCohortArgs A [PnuCohortArgs] object specifying cohort IDs.
#'   Required when [runPnuAnalyses()] loads data from a database; optional
#'   (pass `NULL`) when `pnuDataList` is supplied.
#' @param studyPopulationArgs A [StudyPopulationArgs] object.
#' @param tcpsArgs A [TcpsArgs] object. Pass `NULL` (default) to skip TCPS
#'   fitting and assign propensity score `0.5` uniformly — useful for testing
#'   set-0 equivalence with CohortMethod.
#' @param matchingArgs A [MatchingArgs] object.
#' @param outcomeModelArgs An [OutcomeModelArgs] object.
#' @param bootstrapArgs A [BootstrapArgs] object, or `NULL` (default) to skip
#'   bootstrapping and use Wald-type CIs from the outcome model.
#' @param balanceArgs A [BalanceArgs] object, or `NULL` (default) to skip
#'   covariate balance computation.
#'
#' @return A `PnuAnalysis` R6 object.
#'
#' @seealso [runPnuAnalyses()]
#'
#' @examples
#' analysis <- createPnuAnalysisArgs(
#'   analysisId          = 1L,
#'   description         = "Primary analysis",
#'   studyPopulationArgs = createStudyPopulationArgs(outcomeId = 1L),
#'   matchingArgs        = createMatchingArgs(),
#'   outcomeModelArgs    = createOutcomeModelArgs()
#' )
#'
#' @export
createPnuAnalysisArgs <- function(analysisId = 1L,
                                  description = "",
                                  pnuCohortArgs = NULL,
                                  studyPopulationArgs,
                                  tcpsArgs = NULL,
                                  matchingArgs,
                                  outcomeModelArgs,
                                  bootstrapArgs = NULL,
                                  balanceArgs = NULL) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertInt(analysisId, lower = 1L, add = errorMessages)
  checkmate::assertString(description, add = errorMessages)
  if (!is.null(pnuCohortArgs)) {
    checkmate::assertClass(pnuCohortArgs, "PnuCohortArgs", add = errorMessages)
  }
  checkmate::assertClass(studyPopulationArgs, "StudyPopulationArgs", add = errorMessages)
  if (!is.null(tcpsArgs)) {
    checkmate::assertClass(tcpsArgs, "TcpsArgs", add = errorMessages)
  }
  checkmate::assertClass(matchingArgs, "MatchingArgs", add = errorMessages)
  checkmate::assertClass(outcomeModelArgs, "OutcomeModelArgs", add = errorMessages)
  if (!is.null(bootstrapArgs)) {
    checkmate::assertClass(bootstrapArgs, "BootstrapArgs", add = errorMessages)
  }
  if (!is.null(balanceArgs)) {
    checkmate::assertClass(balanceArgs, "BalanceArgs", add = errorMessages)
  }
  checkmate::reportAssertions(collection = errorMessages)

  PnuAnalysis$new(
    analysisId          = as.integer(analysisId),
    description         = description,
    pnuCohortArgs       = pnuCohortArgs,
    studyPopulationArgs = studyPopulationArgs,
    tcpsArgs            = tcpsArgs,
    matchingArgs        = matchingArgs,
    outcomeModelArgs    = outcomeModelArgs,
    bootstrapArgs       = bootstrapArgs,
    balanceArgs         = balanceArgs
  )
}

# ---- Internal: run one analysis ---------------------------------------------

# Run a single analysis through the full pipeline: study population ->
# (optional) TCPS -> matching -> (optional) balance -> outcome model ->
# (optional) bootstrap. Writes analysis_{id}.rds to outputFolder.
# Returns a one-row tibble for the summary.
.runSingleAnalysis <- function(pnuData, analysis, outputFolder) {
  ParallelLogger::logInfo(
    "Analysis ", analysis$analysisId, ": ", analysis$description
  )

  emptyRow <- function(status) {
    dplyr::tibble(
      analysis_id = analysis$analysisId,
      description = analysis$description,
      log_rr      = NA_real_,
      se_log_rr   = NA_real_,
      ci_95_lb    = NA_real_,
      ci_95_ub    = NA_real_,
      status      = status
    )
  }

  # Step 1 — study population
  pnuData <- createStudyPopulation(pnuData, analysis$studyPopulationArgs)
  pop <- dplyr::collect(pnuData$studyPopulation)

  if (nrow(pop) == 0L) {
    saveRDS(
      list(
        analysisId = analysis$analysisId, description = analysis$description,
        matchedPop = pop,
        outcomeModel = list(
          status = "EMPTY STUDY POPULATION",
          logRr = NA_real_, seLogRr = NA_real_,
          ci95Lb = NA_real_, ci95Ub = NA_real_
        ),
        balance = NULL, bootstrap = NULL
      ),
      file.path(outputFolder, paste0("analysis_", analysis$analysisId, ".rds"))
    )
    return(emptyRow("EMPTY STUDY POPULATION"))
  }

  # Step 2 — TCPS (or uniform PS when tcpsArgs is NULL)
  if (!is.null(analysis$tcpsArgs)) {
    pop <- fitTcps(pop, pnuData, analysis$tcpsArgs)
  } else {
    pop$propensityScore <- 0.5
  }

  # Step 3 — matching
  matchedPop <- suppressMessages(matchOnTcps(pop, analysis$matchingArgs))

  # Step 4 — optional covariate balance
  balanceResult <- NULL
  if (!is.null(analysis$balanceArgs)) {
    balanceResult <- tryCatch(
      computeCovariateBalance(matchedPop, pnuData, analysis$balanceArgs),
      error = function(e) {
        ParallelLogger::logWarn(
          "Balance failed for analysis ", analysis$analysisId, ": ", conditionMessage(e)
        )
        NULL
      }
    )
  }

  # Step 5 — outcome model
  outcomeModel <- fitOutcomeModel(matchedPop, pnuData, analysis$outcomeModelArgs)

  # Step 6 — optional bootstrap (replaces Wald CI in outcomeModel when successful)
  bootstrapResult <- NULL
  if (!is.null(analysis$bootstrapArgs) && outcomeModel$status == "OK") {
    bootstrapResult <- suppressMessages(
      bootstrapCi(matchedPop, pnuData, analysis$outcomeModelArgs, analysis$bootstrapArgs)
    )
    if (bootstrapResult$status == "OK") {
      outcomeModel$seLogRr <- bootstrapResult$seLogRr
      outcomeModel$ci95Lb <- bootstrapResult$ci95Lb
      outcomeModel$ci95Ub <- bootstrapResult$ci95Ub
    }
  }

  saveRDS(
    list(
      analysisId   = analysis$analysisId,
      description  = analysis$description,
      matchedPop   = matchedPop,
      outcomeModel = outcomeModel,
      balance      = balanceResult,
      bootstrap    = bootstrapResult
    ),
    file.path(outputFolder, paste0("analysis_", analysis$analysisId, ".rds"))
  )

  dplyr::tibble(
    analysis_id = analysis$analysisId,
    description = analysis$description,
    log_rr      = outcomeModel$logRr,
    se_log_rr   = outcomeModel$seLogRr,
    ci_95_lb    = outcomeModel$ci95Lb,
    ci_95_ub    = outcomeModel$ci95Ub,
    status      = outcomeModel$status
  )
}

# ---- runPnuAnalyses ---------------------------------------------------------

#' Run a list of prevalent new-user analyses
#'
#' @description
#' Top-level orchestrator for the PNU pipeline. For each [PnuAnalysis] in
#' `pnuAnalysisList`, runs: study-population creation, TCPS fitting (optional),
#' greedy matching, optional covariate balance, outcome modelling, and optional
#' bootstrap CI. Per-analysis results are written as RDS files; a summary CSV
#' is written at the end.
#'
#' @details
#' When `pnuDataList` is `NULL`, the function opens a database connection and
#' calls [getDbPnuData()] for each analysis using that analysis's
#' `pnuCohortArgs`. When `pnuDataList` is provided (a list of [PnuData]
#' objects, one per analysis in the same order), the database loading step is
#' skipped. The `pnuDataList` path is primarily intended for simulation studies
#' and testing.
#'
#' **Note on reference semantics:** [createStudyPopulation()] modifies
#' `pnuData` in place (Andromeda is a reference object). If the same `PnuData`
#' object appears more than once in `pnuDataList`, the `studyPopulation` table
#' will be overwritten by each successive analysis. Use separate `PnuData`
#' objects when analyses have different study-population settings.
#'
#' `parallelComputing = TRUE` is accepted but analyses always run sequentially
#' in this version; parallel support is planned.
#'
#' @param connectionDetails A `DatabaseConnector` connectionDetails object.
#'   Required when `pnuDataList` is `NULL`.
#' @param cdmDatabaseSchema Schema containing the OMOP CDM tables.
#' @param cohortDatabaseSchema Schema containing `cohortTable`.
#' @param cohortTable Name of the cohort table (without schema prefix).
#' @param covariateSettings A covariate settings object from
#'   `FeatureExtraction::createCovariateSettings()`. Required when
#'   `pnuDataList` is `NULL`.
#' @param pnuAnalysisList A list of [PnuAnalysis] objects created by
#'   [createPnuAnalysisArgs()].
#' @param outputFolder Path to the folder where results are written. Created
#'   if it does not exist.
#' @param parallelComputing Logical. Reserved for future use; ignored.
#' @param pnuDataList A list of [PnuData] objects (one per element of
#'   `pnuAnalysisList`) used instead of loading from a database.
#' @param tempEmulationSchema Schema for temp-table emulation. Ignored when
#'   `pnuDataList` is provided.
#'
#' @return A tibble with one row per analysis and columns `analysis_id`,
#'   `description`, `log_rr`, `se_log_rr`, `ci_95_lb`, `ci_95_ub`, `status`,
#'   returned invisibly. The same table is written to
#'   `outputFolder/summary.csv`. Each analysis's full result (matched
#'   population, outcome model, optional balance and bootstrap) is saved as
#'   `outputFolder/analysis_<id>.rds`.
#'
#' @seealso [createPnuAnalysisArgs()], [fitOutcomeModel()], [bootstrapCi()]
#'
#' @references
#' Suissa S, Moodie EE, Dell'Aniello S. Prevalent new-user cohort designs for
#' comparative drug effect studies by time-conditional propensity scores.
#' *Pharmacoepidemiol Drug Saf* 2017;26(4):459-468. \doi{10.1002/pds.4117}
#'
#' @examples
#' \dontrun{
#' analyses <- list(
#'   createPnuAnalysisArgs(
#'     analysisId          = 1L,
#'     description         = "Primary analysis",
#'     pnuCohortArgs       = createPnuCohortArgs(1L, 2L, 3L),
#'     studyPopulationArgs = createStudyPopulationArgs(outcomeId = 1L),
#'     matchingArgs        = createMatchingArgs(),
#'     outcomeModelArgs    = createOutcomeModelArgs()
#'   )
#' )
#' summary <- runPnuAnalyses(
#'   connectionDetails    = myConnectionDetails,
#'   cdmDatabaseSchema    = "cdm",
#'   cohortDatabaseSchema = "results",
#'   cohortTable          = "cohort",
#'   covariateSettings    = FeatureExtraction::createDefaultCovariateSettings(),
#'   pnuAnalysisList      = analyses,
#'   outputFolder         = "output"
#' )
#' }
#'
#' @export
runPnuAnalyses <- function(connectionDetails = NULL,
                           cdmDatabaseSchema = NULL,
                           cohortDatabaseSchema = NULL,
                           cohortTable = NULL,
                           covariateSettings = NULL,
                           pnuAnalysisList,
                           outputFolder,
                           parallelComputing = FALSE,
                           pnuDataList = NULL,
                           tempEmulationSchema = NULL) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertList(pnuAnalysisList, min.len = 1, add = errorMessages)
  checkmate::assertCharacter(outputFolder, len = 1, add = errorMessages)
  checkmate::assertLogical(parallelComputing, len = 1, add = errorMessages)
  if (is.null(pnuDataList)) {
    checkmate::assertClass(connectionDetails, "ConnectionDetails", add = errorMessages)
    checkmate::assertCharacter(cdmDatabaseSchema, len = 1, add = errorMessages)
    checkmate::assertCharacter(cohortDatabaseSchema, len = 1, add = errorMessages)
    checkmate::assertCharacter(cohortTable, len = 1, add = errorMessages)
  } else {
    checkmate::assertList(
      pnuDataList,
      len = length(pnuAnalysisList),
      add = errorMessages
    )
  }
  checkmate::reportAssertions(collection = errorMessages)

  for (analysis in pnuAnalysisList) {
    checkmate::assertClass(analysis, "PnuAnalysis")
    analysis$validate()
  }

  if (!dir.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }

  nAnalyses <- length(pnuAnalysisList)
  summaryRows <- vector("list", nAnalyses)

  for (i in seq_len(nAnalyses)) {
    analysis <- pnuAnalysisList[[i]]
    ParallelLogger::logInfo(
      "Analysis ", i, " of ", nAnalyses,
      " (id=", analysis$analysisId, ")"
    )

    if (!is.null(pnuDataList)) {
      checkmate::assertClass(pnuDataList[[i]], "PnuData")
      summaryRows[[i]] <- tryCatch(
        .runSingleAnalysis(pnuDataList[[i]], analysis, outputFolder),
        error = function(e) {
          ParallelLogger::logWarn(
            "Analysis ", analysis$analysisId, " failed: ", conditionMessage(e)
          )
          dplyr::tibble(
            analysis_id = analysis$analysisId,
            description = analysis$description,
            log_rr      = NA_real_,
            se_log_rr   = NA_real_,
            ci_95_lb    = NA_real_,
            ci_95_ub    = NA_real_,
            status      = paste("FAILED:", conditionMessage(e))
          )
        }
      )
    } else {
      conn <- DatabaseConnector::connect(connectionDetails)
      pnuData <- NULL
      summaryRows[[i]] <- tryCatch(
        {
          pnuData <- getDbPnuData(
            connection           = conn,
            cdmDatabaseSchema    = cdmDatabaseSchema,
            cohortDatabaseSchema = cohortDatabaseSchema,
            cohortTable          = cohortTable,
            pnuCohortArgs        = analysis$pnuCohortArgs,
            covariateSettings    = covariateSettings,
            tempEmulationSchema  = tempEmulationSchema
          )
          .runSingleAnalysis(pnuData, analysis, outputFolder)
        },
        error = function(e) {
          ParallelLogger::logWarn(
            "Analysis ", analysis$analysisId, " failed: ", conditionMessage(e)
          )
          dplyr::tibble(
            analysis_id = analysis$analysisId,
            description = analysis$description,
            log_rr      = NA_real_,
            se_log_rr   = NA_real_,
            ci_95_lb    = NA_real_,
            ci_95_ub    = NA_real_,
            status      = paste("FAILED:", conditionMessage(e))
          )
        },
        finally = {
          try(DatabaseConnector::disconnect(conn), silent = TRUE)
          if (!is.null(pnuData)) try(Andromeda::close(pnuData), silent = TRUE)
        }
      )
    }
  }

  summary <- dplyr::bind_rows(summaryRows)
  utils::write.csv(summary,
    file = file.path(outputFolder, "summary.csv"),
    row.names = FALSE
  )
  message("Results written to: ", outputFolder)

  invisible(summary)
}
