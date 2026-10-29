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

# ---- exportToCsv ------------------------------------------------------------

#' Export analysis results to CSV files
#'
#' @description
#' Reads `summary.csv` and per-analysis `.rds` files produced by
#' [runPnuAnalyses()] and writes three flat CSV files to `exportFolder` whose
#' column names match the results data model specification:
#'
#' * `analysis.csv` — one row per analysis.
#' * `estimate.csv` — point estimate and CI per analysis; calibrated columns
#'   are included when present in `summary.csv` (i.e. after
#'   [calibrateEstimates()] has been applied), otherwise filled with `NA`.
#' * `covariate_balance.csv` — covariate balance rows; omitted when no
#'   analysis produced balance data.
#'
#' Every file receives a leading `database_id` column so that exports from
#' multiple databases can be stacked for use with Strategus or a Shiny results
#' viewer.
#'
#' @details
#' `minCellCount` is accepted for forward compatibility; the current data model
#' stores log-scale estimates and proportions rather than raw counts, so no
#' rows are suppressed at present.
#'
#' @param outputFolder Path to the folder produced by [runPnuAnalyses()].
#'   Must contain `summary.csv`.
#' @param exportFolder Path to the folder where CSV files are written.
#'   Created if it does not exist.
#' @param databaseId Character string identifying the source database.
#'   Written as the first column of every exported file.
#' @param minCellCount Minimum allowable cell count; reserved for future
#'   small-cell suppression. Default: `5L`.
#'
#' @return `NULL` invisibly.
#'
#' @seealso [runPnuAnalyses()], [calibrateEstimates()], [uploadResults()]
#'
#' @examples
#' \dontrun{
#' runPnuAnalyses(
#'   connectionDetails = connectionDetails,
#'   cdmDatabaseSchema = "cdm",
#'   cohortDatabaseSchema = "cohorts",
#'   cohortTable = "cohort",
#'   covariateSettings = covariateSettings,
#'   pnuAnalysisList = analysisList,
#'   outputFolder = "output"
#' )
#' exportToCsv(
#'   outputFolder = "output",
#'   exportFolder = "export",
#'   databaseId   = "Synpuf"
#' )
#' }
#'
#' @export
exportToCsv <- function(outputFolder,
                        exportFolder,
                        databaseId,
                        minCellCount = 5L) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertCharacter(outputFolder, len = 1, add = errorMessages)
  checkmate::assertDirectoryExists(outputFolder, add = errorMessages)
  checkmate::assertCharacter(exportFolder, len = 1, add = errorMessages)
  checkmate::assertCharacter(databaseId, len = 1, add = errorMessages)
  checkmate::assertInt(minCellCount, lower = 0L, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  summaryPath <- file.path(outputFolder, "summary.csv")
  if (!file.exists(summaryPath)) {
    stop("summary.csv not found in outputFolder: ", outputFolder)
  }

  if (!dir.exists(exportFolder)) {
    dir.create(exportFolder, recursive = TRUE)
  }

  summary <- utils::read.csv(summaryPath, stringsAsFactors = FALSE)

  # ---- analysis.csv ---------------------------------------------------
  analysisData <- data.frame(
    database_id = databaseId,
    analysis_id = as.integer(summary$analysis_id),
    description = as.character(summary$description),
    stringsAsFactors = FALSE
  )
  utils::write.csv(
    analysisData,
    file = file.path(exportFolder, "analysis.csv"),
    row.names = FALSE
  )
  ParallelLogger::logInfo("Exported ", nrow(analysisData), " rows to analysis.csv")

  # ---- estimate.csv ---------------------------------------------------
  calibCols <- c(
    "calibrated_log_rr", "calibrated_se_log_rr", "calibrated_p",
    "calibrated_ci_95_lb", "calibrated_ci_95_ub"
  )
  estimateData <- data.frame(
    database_id = databaseId,
    analysis_id = as.integer(summary$analysis_id),
    log_rr = as.numeric(summary$log_rr),
    se_log_rr = as.numeric(summary$se_log_rr),
    ci_95_lb = as.numeric(summary$ci_95_lb),
    ci_95_ub = as.numeric(summary$ci_95_ub),
    status = as.character(summary$status),
    stringsAsFactors = FALSE
  )
  for (col in calibCols) {
    estimateData[[col]] <- if (col %in% names(summary)) {
      as.numeric(summary[[col]])
    } else {
      NA_real_
    }
  }
  utils::write.csv(
    estimateData,
    file = file.path(exportFolder, "estimate.csv"),
    row.names = FALSE
  )
  ParallelLogger::logInfo("Exported ", nrow(estimateData), " rows to estimate.csv")

  # ---- covariate_balance.csv (from per-analysis RDS files) ------------
  balanceRows <- vector("list", nrow(summary))
  for (i in seq_len(nrow(summary))) {
    rdsPath <- file.path(
      outputFolder,
      paste0("analysis_", summary$analysis_id[i], ".rds")
    )
    if (!file.exists(rdsPath)) next
    result <- readRDS(rdsPath)
    bal <- result$balance
    if (is.null(bal) || nrow(bal) == 0L) next
    balanceRows[[i]] <- data.frame(
      database_id = databaseId,
      analysis_id = summary$analysis_id[i],
      covariate_id = as.numeric(bal$covariate_id),
      covariate_name = as.character(bal$covariate_name),
      before_matching_mean_target = as.numeric(bal$beforeMatchingMeanTarget),
      before_matching_mean_comparator = as.numeric(bal$beforeMatchingMeanComparator),
      before_matching_smd = as.numeric(bal$beforeMatchingSmd),
      after_matching_mean_target = as.numeric(bal$afterMatchingMeanTarget),
      after_matching_mean_comparator = as.numeric(bal$afterMatchingMeanComparator),
      after_matching_smd = as.numeric(bal$afterMatchingSmd),
      stringsAsFactors = FALSE
    )
  }
  balanceData <- do.call(rbind, Filter(Negate(is.null), balanceRows))

  if (!is.null(balanceData) && nrow(balanceData) > 0L) {
    utils::write.csv(
      balanceData,
      file = file.path(exportFolder, "covariate_balance.csv"),
      row.names = FALSE
    )
    ParallelLogger::logInfo(
      "Exported ", nrow(balanceData), " rows to covariate_balance.csv"
    )
  }

  invisible(NULL)
}
