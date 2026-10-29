# ---- helpers ----------------------------------------------------------------

makeOutputFolder <- function(seed = 1L) {
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
  outDir <- file.path(tempdir(), paste0("pnu_exp_", sample.int(1e6, 1)))
  suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = analyses,
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  outDir
}

# ---- argument validation ----------------------------------------------------

test_that("exportToCsv errors when outputFolder does not exist", {
  expect_error(
    exportToCsv(
      outputFolder = "/nonexistent/path",
      exportFolder = tempdir(),
      databaseId   = "test"
    )
  )
})

test_that("exportToCsv errors when summary.csv is missing", {
  emptyDir <- file.path(tempdir(), paste0("pnu_empty_", sample.int(1e6, 1)))
  dir.create(emptyDir)
  expect_error(
    exportToCsv(
      outputFolder = emptyDir,
      exportFolder = tempdir(),
      databaseId   = "test"
    ),
    regexp = "summary.csv"
  )
})

test_that("exportToCsv errors on non-character databaseId", {
  outDir <- makeOutputFolder(seed = 1L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  expect_error(
    exportToCsv(
      outputFolder = outDir,
      exportFolder = expDir,
      databaseId   = 123L
    )
  )
})

# ---- file creation ----------------------------------------------------------

test_that("exportToCsv creates exportFolder when it does not exist", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 10L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_new_", sample.int(1e6, 1)))
  expect_false(dir.exists(expDir))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  expect_true(dir.exists(expDir))
})

test_that("exportToCsv creates analysis.csv", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 11L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  expect_true(file.exists(file.path(expDir, "analysis.csv")))
})

test_that("exportToCsv creates estimate.csv", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 12L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  expect_true(file.exists(file.path(expDir, "estimate.csv")))
})

test_that("exportToCsv returns NULL invisibly", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 13L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  result <- suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  expect_null(result)
})

# ---- analysis.csv contents --------------------------------------------------

test_that("analysis.csv has database_id, analysis_id, description columns", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 20L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  df <- read.csv(file.path(expDir, "analysis.csv"), stringsAsFactors = FALSE)
  expect_true("database_id" %in% names(df))
  expect_true("analysis_id" %in% names(df))
  expect_true("description" %in% names(df))
})

test_that("analysis.csv has one row per analysis", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 21L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  df <- read.csv(file.path(expDir, "analysis.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(df), 1L)
})

test_that("analysis.csv database_id matches supplied argument", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 22L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "myDb"))
  df <- read.csv(file.path(expDir, "analysis.csv"), stringsAsFactors = FALSE)
  expect_equal(df$database_id[1], "myDb")
})

test_that("analysis.csv analysis_id matches the analysis", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 23L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  df <- read.csv(file.path(expDir, "analysis.csv"), stringsAsFactors = FALSE)
  expect_equal(df$analysis_id[1], 1L)
})

# ---- estimate.csv contents --------------------------------------------------

test_that("estimate.csv has all required spec columns plus database_id", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 30L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  df <- read.csv(file.path(expDir, "estimate.csv"), stringsAsFactors = FALSE)
  specCols <- c(
    "analysis_id", "log_rr", "se_log_rr", "ci_95_lb", "ci_95_ub",
    "calibrated_log_rr", "calibrated_se_log_rr", "calibrated_p",
    "calibrated_ci_95_lb", "calibrated_ci_95_ub", "status"
  )
  expect_true(all(specCols %in% names(df)))
  expect_true("database_id" %in% names(df))
})

test_that("estimate.csv has one row per analysis", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 31L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  df <- read.csv(file.path(expDir, "estimate.csv"), stringsAsFactors = FALSE)
  expect_equal(nrow(df), 1L)
})

test_that("estimate.csv log_rr is finite when analysis succeeded", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 32L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  df <- read.csv(file.path(expDir, "estimate.csv"), stringsAsFactors = FALSE)
  ok <- df[df$status == "OK", ]
  if (nrow(ok) > 0L) {
    expect_true(is.finite(ok$log_rr[1]))
  }
})

test_that("calibrated columns are NA when no calibration was run", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 33L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  df <- read.csv(file.path(expDir, "estimate.csv"), stringsAsFactors = FALSE)
  expect_true(all(is.na(df$calibrated_log_rr)))
})

# ---- covariate_balance.csv (no balance in base analyses) --------------------

test_that("covariate_balance.csv is not created when no analysis has balance data", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 40L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  # makeOutputFolder uses no balanceArgs, so no balance data
  expect_false(file.exists(file.path(expDir, "covariate_balance.csv")))
})

# ---- spec coverage ----------------------------------------------------------

test_that("analysis.csv headers are a superset of spec columns for analysis table", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 50L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  spec <- read.csv(
    system.file("csv", "resultsDataModelSpecification.csv",
      package = "PrevalentNewUser"
    ),
    stringsAsFactors = FALSE
  )
  specCols <- spec$columnName[spec$tableName == "analysis"]
  df <- read.csv(file.path(expDir, "analysis.csv"), stringsAsFactors = FALSE)
  expect_true(all(specCols %in% names(df)))
})

test_that("estimate.csv headers are a superset of spec columns for estimate table", {
  skip_if_not_installed("Cyclops")
  outDir <- makeOutputFolder(seed = 51L)
  expDir <- file.path(tempdir(), paste0("pnu_ex_", sample.int(1e6, 1)))
  suppressMessages(exportToCsv(outDir, expDir, databaseId = "db1"))
  spec <- read.csv(
    system.file("csv", "resultsDataModelSpecification.csv",
      package = "PrevalentNewUser"
    ),
    stringsAsFactors = FALSE
  )
  specCols <- spec$columnName[spec$tableName == "estimate"]
  df <- read.csv(file.path(expDir, "estimate.csv"), stringsAsFactors = FALSE)
  expect_true(all(specCols %in% names(df)))
})
