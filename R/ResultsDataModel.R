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

.getResultsSpec <- function() {
  utils::read.csv(
    system.file("csv", "resultsDataModelSpecification.csv",
      package = "PrevalentNewUser"
    ),
    stringsAsFactors = FALSE
  )
}

.fullTableName <- function(databaseSchema, tablePrefix, tableName) {
  bare <- paste0(tablePrefix, tableName)
  if (is.null(databaseSchema) || nchar(databaseSchema) == 0L) bare else paste0(databaseSchema, ".", bare)
}

# Build a DROP + CREATE TABLE SQL statement for one table from spec rows.
.buildCreateTableSql <- function(specRows, fullName) {
  colDefs <- vapply(seq_len(nrow(specRows)), function(i) {
    row <- specRows[i, ]
    notNull <- if (isTRUE(row$isRequired == "Yes")) " NOT NULL" else ""
    paste0("  ", row$columnName, " ", row$dataType, notNull)
  }, character(1L))

  pkCols <- specRows$columnName[specRows$primaryKey == "Yes"]
  pkClause <- if (length(pkCols) > 0L) {
    paste0(",\n  PRIMARY KEY (", paste(pkCols, collapse = ", "), ")")
  } else {
    ""
  }

  paste0(
    "DROP TABLE IF EXISTS ", fullName, ";\n",
    "CREATE TABLE ", fullName, " (\n",
    paste(colDefs, collapse = ",\n"),
    pkClause,
    "\n);"
  )
}

# ---- createResultsDataModel -------------------------------------------------

#' Create the PNU results data model in a database
#'
#' @description
#' Reads the bundled results-data-model specification
#' (`inst/csv/resultsDataModelSpecification.csv`) and creates three tables in
#' the target database:
#'
#' * `<tablePrefix>pnu_analysis` — one row per analysis.
#' * `<tablePrefix>pnu_estimate` — point estimate and CI per analysis.
#' * `<tablePrefix>pnu_covariate_balance` — SMDs before and after matching.
#'
#' Existing tables with the same names are **dropped and recreated**.
#'
#' @param connectionDetails A `DatabaseConnector` connectionDetails object.
#' @param databaseSchema Schema in which to create the tables.
#' @param tablePrefix Character prefix prepended to every table name. Default:
#'   `"pnu_"`.  Pass `""` to use bare table names.
#'
#' @return `NULL` invisibly.
#'
#' @seealso [uploadResults()]
#'
#' @examples
#' \dontrun{
#' cd <- DatabaseConnector::createConnectionDetails(
#'   dbms   = "sqlite",
#'   server = tempfile(fileext = ".sqlite")
#' )
#' createResultsDataModel(cd, databaseSchema = "main")
#' }
#'
#' @export
createResultsDataModel <- function(connectionDetails,
                                   databaseSchema,
                                   tablePrefix = "pnu_") {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertClass(connectionDetails, "ConnectionDetails", add = errorMessages)
  checkmate::assertCharacter(databaseSchema, len = 1, add = errorMessages)
  checkmate::assertCharacter(tablePrefix, len = 1, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  spec <- .getResultsSpec()
  tableNames <- unique(spec$tableName)

  conn <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  for (tbl in tableNames) {
    specRows <- spec[spec$tableName == tbl, ]
    fullName <- .fullTableName(databaseSchema, tablePrefix, tbl)
    sql <- .buildCreateTableSql(specRows, fullName)
    sql <- SqlRender::translate(sql, targetDialect = conn@dbms)
    ParallelLogger::logInfo("Creating table: ", fullName)
    DatabaseConnector::executeSql(conn, sql,
      progressBar = FALSE, reportOverallTime = FALSE
    )
  }

  invisible(NULL)
}

# ---- uploadResults ----------------------------------------------------------

#' Upload analysis results to a database
#'
#' @description
#' Reads `summary.csv` and per-analysis `.rds` files from `resultsFolder` (as
#' produced by [runPnuAnalyses()]) and inserts the data into the results tables
#' created by [createResultsDataModel()].
#'
#' @details
#' `summary.csv` supplies `pnu_analysis` (analysisId, description) and
#' `pnu_estimate` (point estimates, CIs, status). If the summary contains
#' calibrated-estimate columns (added by [calibrateEstimates()]), those are
#' also uploaded; otherwise the calibrated columns are `NULL`.
#'
#' Each `analysis_<id>.rds` is read for covariate balance data. If
#' `result$balance` is non-`NULL`, rows are inserted into
#' `pnu_covariate_balance`.
#'
#' Tables must already exist (call [createResultsDataModel()] first).
#'
#' @param connectionDetails A `DatabaseConnector` connectionDetails object.
#' @param databaseSchema Schema containing the results tables.
#' @param tablePrefix Prefix used when the tables were created. Default:
#'   `"pnu_"`.
#' @param resultsFolder Path to the folder produced by [runPnuAnalyses()].
#'
#' @return `NULL` invisibly.
#'
#' @seealso [createResultsDataModel()], [runPnuAnalyses()]
#'
#' @examples
#' \dontrun{
#' cd <- DatabaseConnector::createConnectionDetails(
#'   dbms   = "sqlite",
#'   server = "results.sqlite"
#' )
#' createResultsDataModel(cd, databaseSchema = "main")
#' uploadResults(cd, databaseSchema = "main", resultsFolder = "output")
#' }
#'
#' @export
uploadResults <- function(connectionDetails,
                          databaseSchema,
                          tablePrefix = "pnu_",
                          resultsFolder) {
  errorMessages <- checkmate::makeAssertCollection()
  checkmate::assertClass(connectionDetails, "ConnectionDetails", add = errorMessages)
  checkmate::assertCharacter(databaseSchema, len = 1, add = errorMessages)
  checkmate::assertCharacter(tablePrefix, len = 1, add = errorMessages)
  checkmate::assertCharacter(resultsFolder, len = 1, add = errorMessages)
  checkmate::assertDirectoryExists(resultsFolder, add = errorMessages)
  checkmate::reportAssertions(collection = errorMessages)

  summaryPath <- file.path(resultsFolder, "summary.csv")
  if (!file.exists(summaryPath)) {
    stop("summary.csv not found in resultsFolder: ", resultsFolder)
  }

  summary <- utils::read.csv(summaryPath, stringsAsFactors = FALSE)

  # ---- pnu_analysis ---------------------------------------------------
  analysisData <- data.frame(
    analysis_id = as.integer(summary$analysis_id),
    description = as.character(summary$description),
    stringsAsFactors = FALSE
  )

  # ---- pnu_estimate ---------------------------------------------------
  calibCols <- c(
    "calibrated_log_rr", "calibrated_se_log_rr", "calibrated_p",
    "calibrated_ci_95_lb", "calibrated_ci_95_ub"
  )
  estimateData <- data.frame(
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

  # ---- pnu_covariate_balance (from individual RDS files) ------------------
  balanceRows <- vector("list", nrow(summary))
  for (i in seq_len(nrow(summary))) {
    rdsPath <- file.path(
      resultsFolder,
      paste0("analysis_", summary$analysis_id[i], ".rds")
    )
    if (!file.exists(rdsPath)) next
    result <- readRDS(rdsPath)
    bal <- result$balance
    if (is.null(bal) || nrow(bal) == 0L) next
    balanceRows[[i]] <- data.frame(
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

  # ---- Upload -------------------------------------------------------------
  conn <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  DatabaseConnector::insertTable(
    connection = conn,
    databaseSchema = databaseSchema,
    tableName = paste0(tablePrefix, "analysis"),
    data = analysisData,
    dropTableIfExists = FALSE,
    createTable = FALSE
  )
  ParallelLogger::logInfo("Uploaded ", nrow(analysisData), " rows to analysis")

  DatabaseConnector::insertTable(
    connection = conn,
    databaseSchema = databaseSchema,
    tableName = paste0(tablePrefix, "estimate"),
    data = estimateData,
    dropTableIfExists = FALSE,
    createTable = FALSE
  )
  ParallelLogger::logInfo("Uploaded ", nrow(estimateData), " rows to estimate")

  if (!is.null(balanceData) && nrow(balanceData) > 0L) {
    DatabaseConnector::insertTable(
      connection = conn,
      databaseSchema = databaseSchema,
      tableName = paste0(tablePrefix, "covariate_balance"),
      data = balanceData,
      dropTableIfExists = FALSE,
      createTable = FALSE
    )
    ParallelLogger::logInfo(
      "Uploaded ", nrow(balanceData), " rows to covariate_balance"
    )
  }

  invisible(NULL)
}
