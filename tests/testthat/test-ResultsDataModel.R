# ---- helpers ----------------------------------------------------------------

makeSqliteDetails <- function() {
  # Evaluate tempfile() once and store in 'f' so that createConnectionDetails
  # captures the symbol 'f' (always the same path) rather than re-evaluating
  # tempfile() on every connect() call (which would produce a new path).
  f <- normalizePath(tempfile(fileext = ".sqlite"), mustWork = FALSE)
  DatabaseConnector::createConnectionDetails(dbms = "sqlite", server = f)
}

makeResultsFolder <- function(seed = 1L) {
  skip_if_not_installed("Cyclops")
  simArgs <- createSimulationArgs(
    nSwitchers         = 200L,
    nComparatorsPerSet = 200L,
    nExposureSets      = 1L,
    nCovariates        = 0L,
    outcomeBaseRate    = 0.2,
    logRr              = log(1.5),
    seed               = seed
  )
  pnuData <- simulatePnuData(simArgs)
  on.exit(Andromeda::close(pnuData), add = TRUE)

  analyses <- list(
    createPnuAnalysisArgs(
      analysisId          = 1L,
      description         = "primary",
      studyPopulationArgs = createStudyPopulationArgs(
        outcomeId = 1L, requireTimeAtRisk = FALSE
      ),
      matchingArgs     = createMatchingArgs(caliper = 0L),
      outcomeModelArgs = createOutcomeModelArgs()
    )
  )
  outDir <- file.path(tempdir(), paste0("pnu_rdm_", sample.int(1e6, 1)))
  suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = analyses,
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  outDir
}

# ---- CSV specification validation -------------------------------------------

test_that("resultsDataModelSpecification.csv is readable", {
  path <- system.file("csv", "resultsDataModelSpecification.csv",
    package = "PrevalentNewUser"
  )
  expect_true(file.exists(path))
  spec <- read.csv(path, stringsAsFactors = FALSE)
  expect_true(is.data.frame(spec))
})

test_that("spec has required columns", {
  spec <- read.csv(
    system.file("csv", "resultsDataModelSpecification.csv",
      package = "PrevalentNewUser"
    ),
    stringsAsFactors = FALSE
  )
  required <- c("tableName", "columnName", "dataType", "isRequired", "primaryKey")
  expect_true(all(required %in% names(spec)))
})

test_that("spec contains the three expected logical table names", {
  spec <- read.csv(
    system.file("csv", "resultsDataModelSpecification.csv",
      package = "PrevalentNewUser"
    ),
    stringsAsFactors = FALSE
  )
  tbls <- unique(spec$tableName)
  expect_setequal(tbls, c("analysis", "estimate", "covariate_balance"))
})

test_that("every table has at least one primary-key column", {
  spec <- read.csv(
    system.file("csv", "resultsDataModelSpecification.csv",
      package = "PrevalentNewUser"
    ),
    stringsAsFactors = FALSE
  )
  for (tbl in unique(spec$tableName)) {
    pkRows <- spec[spec$tableName == tbl & spec$primaryKey == "Yes", ]
    expect_gt(nrow(pkRows), 0L, label = paste("PK for", tbl))
  }
})

test_that("analysis_id appears as primary key in analysis table", {
  spec <- read.csv(
    system.file("csv", "resultsDataModelSpecification.csv",
      package = "PrevalentNewUser"
    ),
    stringsAsFactors = FALSE
  )
  row <- spec[spec$tableName == "analysis" & spec$columnName == "analysis_id", ]
  expect_equal(row$primaryKey, "Yes")
})

# ---- createResultsDataModel -------------------------------------------------

test_that("createResultsDataModel errors on non-ConnectionDetails argument", {
  expect_error(createResultsDataModel(list(), databaseSchema = "main"))
})

test_that("createResultsDataModel creates pnu_analysis table on SQLite", {
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main")
  conn <- DatabaseConnector::connect(cd)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  expect_true(DatabaseConnector::existsTable(conn,
    databaseSchema = NULL, tableName = "pnu_analysis"
  ))
})

test_that("createResultsDataModel creates all three tables", {
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main")
  conn <- DatabaseConnector::connect(cd)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  tbls <- DatabaseConnector::getTableNames(conn, databaseSchema = NULL)
  expect_true("pnu_analysis" %in% tbls)
  expect_true("pnu_estimate" %in% tbls)
  expect_true("pnu_covariate_balance" %in% tbls)
})

test_that("createResultsDataModel with empty tablePrefix uses bare names", {
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main", tablePrefix = "")
  conn <- DatabaseConnector::connect(cd)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  tbls <- DatabaseConnector::getTableNames(conn, databaseSchema = NULL)
  expect_true("analysis" %in% tbls)
  expect_true("estimate" %in% tbls)
})

test_that("pnu_analysis table has analysis_id and description columns", {
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main")
  conn <- DatabaseConnector::connect(cd)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  cols <- names(DatabaseConnector::querySql(
    conn, "SELECT * FROM pnu_analysis WHERE 1=0;",
    snakeCaseToCamelCase = FALSE
  ))
  expect_true("analysis_id" %in% cols)
  expect_true("description" %in% cols)
})

test_that("pnu_estimate table has status, log_rr, and calibrated columns", {
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main")
  conn <- DatabaseConnector::connect(cd)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  cols <- names(DatabaseConnector::querySql(
    conn, "SELECT * FROM pnu_estimate WHERE 1=0;",
    snakeCaseToCamelCase = FALSE
  ))
  expect_true("status" %in% cols)
  expect_true("log_rr" %in% cols)
  expect_true("calibrated_log_rr" %in% cols)
})

test_that("createResultsDataModel is idempotent (second call drops and recreates)", {
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main")
  expect_no_error(createResultsDataModel(cd, databaseSchema = "main"))
})

# ---- uploadResults ----------------------------------------------------------

test_that("uploadResults errors when resultsFolder does not exist", {
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main")
  expect_error(
    uploadResults(cd, databaseSchema = "main", resultsFolder = "/nonexistent/path")
  )
})

test_that("uploadResults inserts one row into pnu_analysis per analysis", {
  skip_if_not_installed("Cyclops")
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main")
  folder <- makeResultsFolder(seed = 1L)

  suppressMessages(uploadResults(cd, databaseSchema = "main", resultsFolder = folder))

  conn <- DatabaseConnector::connect(cd)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)
  n <- DatabaseConnector::querySql(
    conn, "SELECT COUNT(*) AS n FROM pnu_analysis;",
    snakeCaseToCamelCase = FALSE
  )[1, 1]
  expect_equal(n, 1L)
})

test_that("uploadResults inserts correct analysis_id into pnu_analysis", {
  skip_if_not_installed("Cyclops")
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main")
  folder <- makeResultsFolder(seed = 2L)

  suppressMessages(uploadResults(cd, databaseSchema = "main", resultsFolder = folder))

  conn <- DatabaseConnector::connect(cd)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)
  id <- DatabaseConnector::querySql(
    conn, "SELECT analysis_id FROM pnu_analysis;",
    snakeCaseToCamelCase = FALSE
  )[1, 1]
  expect_equal(id, 1L)
})

test_that("uploadResults inserts one row into pnu_estimate per analysis", {
  skip_if_not_installed("Cyclops")
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main")
  folder <- makeResultsFolder(seed = 3L)

  suppressMessages(uploadResults(cd, databaseSchema = "main", resultsFolder = folder))

  conn <- DatabaseConnector::connect(cd)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)
  n <- DatabaseConnector::querySql(
    conn, "SELECT COUNT(*) AS n FROM pnu_estimate;",
    snakeCaseToCamelCase = FALSE
  )[1, 1]
  expect_equal(n, 1L)
})

test_that("uploaded estimate has finite log_rr when analysis succeeded", {
  skip_if_not_installed("Cyclops")
  cd <- makeSqliteDetails()
  createResultsDataModel(cd, databaseSchema = "main")
  folder <- makeResultsFolder(seed = 4L)

  suppressMessages(uploadResults(cd, databaseSchema = "main", resultsFolder = folder))

  conn <- DatabaseConnector::connect(cd)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)
  logRr <- DatabaseConnector::querySql(
    conn, "SELECT log_rr FROM pnu_estimate;",
    snakeCaseToCamelCase = FALSE
  )[1, 1]
  expect_true(is.finite(logRr))
})
