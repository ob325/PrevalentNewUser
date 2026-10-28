# ---- helpers ----------------------------------------------------------------

makeSimPnu <- function(nSwitchers = 250L, logRr = log(1.5), seed = 1L) {
  simArgs <- createSimulationArgs(
    nSwitchers         = nSwitchers,
    nComparatorsPerSet = nSwitchers,
    nExposureSets      = 1L,
    nCovariates        = 0L,
    outcomeBaseRate    = 0.2,
    logRr              = logRr,
    seed               = seed
  )
  simulatePnuData(simArgs)
}

defaultSpArgs <- function() {
  createStudyPopulationArgs(outcomeId = 1L, requireTimeAtRisk = FALSE)
}

makeDefaultAnalysis <- function(analysisId = 1L, description = "test") {
  createPnuAnalysisArgs(
    analysisId          = analysisId,
    description         = description,
    studyPopulationArgs = defaultSpArgs(),
    matchingArgs        = createMatchingArgs(caliper = 0L),
    outcomeModelArgs    = createOutcomeModelArgs()
  )
}

# ---- createPnuAnalysisArgs --------------------------------------------------

test_that("createPnuAnalysisArgs errors when studyPopulationArgs is missing", {
  expect_error(
    createPnuAnalysisArgs(
      matchingArgs     = createMatchingArgs(),
      outcomeModelArgs = createOutcomeModelArgs()
    )
  )
})

test_that("createPnuAnalysisArgs errors when studyPopulationArgs is wrong class", {
  expect_error(
    createPnuAnalysisArgs(
      studyPopulationArgs = list(outcomeId = 1L),
      matchingArgs        = createMatchingArgs(),
      outcomeModelArgs    = createOutcomeModelArgs()
    )
  )
})

test_that("createPnuAnalysisArgs errors when matchingArgs is wrong class", {
  expect_error(
    createPnuAnalysisArgs(
      studyPopulationArgs = defaultSpArgs(),
      matchingArgs        = list(),
      outcomeModelArgs    = createOutcomeModelArgs()
    )
  )
})

test_that("createPnuAnalysisArgs errors when outcomeModelArgs is wrong class", {
  expect_error(
    createPnuAnalysisArgs(
      studyPopulationArgs = defaultSpArgs(),
      matchingArgs        = createMatchingArgs(),
      outcomeModelArgs    = list()
    )
  )
})

test_that("createPnuAnalysisArgs returns PnuAnalysis with default analysisId = 1", {
  a <- makeDefaultAnalysis()
  expect_s3_class(a, "PnuAnalysis")
  expect_equal(a$analysisId, 1L)
})

test_that("createPnuAnalysisArgs stores description", {
  a <- makeDefaultAnalysis(description = "sensitivity")
  expect_equal(a$description, "sensitivity")
})

test_that("createPnuAnalysisArgs stores all supplied args", {
  sp <- defaultSpArgs()
  ma <- createMatchingArgs(caliper = 0.1)
  om <- createOutcomeModelArgs(modelType = "logistic", stratified = FALSE)
  a <- createPnuAnalysisArgs(
    studyPopulationArgs = sp,
    matchingArgs        = ma,
    outcomeModelArgs    = om
  )
  expect_s3_class(a$studyPopulationArgs, "StudyPopulationArgs")
  expect_s3_class(a$matchingArgs, "MatchingArgs")
  expect_s3_class(a$outcomeModelArgs, "OutcomeModelArgs")
  expect_null(a$tcpsArgs)
  expect_null(a$bootstrapArgs)
  expect_null(a$balanceArgs)
})

test_that("createPnuAnalysisArgs JSON round-trip preserves analysisId and description", {
  original <- makeDefaultAnalysis(analysisId = 7L, description = "round-trip test")
  restored <- PnuAnalysis$new(json = original$toJson())
  expect_equal(restored$analysisId, 7L)
  expect_equal(restored$description, "round-trip test")
})

test_that("PnuAnalysis validate errors on analysisId < 1", {
  a <- makeDefaultAnalysis()
  a$analysisId <- 0L
  expect_error(a$validate())
})

# ---- runPnuAnalyses ---------------------------------------------------------

test_that("runPnuAnalyses errors on empty pnuAnalysisList", {
  expect_error(
    runPnuAnalyses(
      pnuAnalysisList = list(),
      outputFolder    = tempdir(),
      pnuDataList     = list()
    )
  )
})

test_that("runPnuAnalyses creates outputFolder when absent", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu()
  on.exit(Andromeda::close(pnuData), add = TRUE)

  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  expect_false(dir.exists(outDir))
  suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = list(makeDefaultAnalysis()),
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  expect_true(dir.exists(outDir))
})

test_that("runPnuAnalyses writes summary.csv", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu()
  on.exit(Andromeda::close(pnuData), add = TRUE)

  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = list(makeDefaultAnalysis()),
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  expect_true(file.exists(file.path(outDir, "summary.csv")))
})

test_that("summary.csv has required columns", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu()
  on.exit(Andromeda::close(pnuData), add = TRUE)

  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = list(makeDefaultAnalysis()),
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  df <- read.csv(file.path(outDir, "summary.csv"))
  expected <- c("analysis_id", "description", "log_rr", "se_log_rr",
                "ci_95_lb", "ci_95_ub", "status")
  expect_true(all(expected %in% names(df)))
})

test_that("summary.csv has one row per analysis", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu(seed = 2L)
  on.exit(Andromeda::close(pnuData), add = TRUE)

  analyses <- list(
    makeDefaultAnalysis(analysisId = 1L, description = "A1"),
    makeDefaultAnalysis(analysisId = 2L, description = "A2")
  )
  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = analyses,
      outputFolder    = outDir,
      pnuDataList     = list(pnuData, pnuData)
    )
  )
  df <- read.csv(file.path(outDir, "summary.csv"))
  expect_equal(nrow(df), 2L)
})

test_that("analysis RDS file exists for each analysis", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu(seed = 3L)
  on.exit(Andromeda::close(pnuData), add = TRUE)

  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = list(makeDefaultAnalysis(analysisId = 5L)),
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  expect_true(file.exists(file.path(outDir, "analysis_5.rds")))
})

test_that("loaded RDS has required fields", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu(seed = 4L)
  on.exit(Andromeda::close(pnuData), add = TRUE)

  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = list(makeDefaultAnalysis()),
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  result <- readRDS(file.path(outDir, "analysis_1.rds"))
  expect_true(all(c("analysisId", "description", "matchedPop", "outcomeModel") %in%
    names(result)))
})

test_that("runPnuAnalyses returns status OK for well-specified analysis", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu(nSwitchers = 300L, logRr = log(2), seed = 5L)
  on.exit(Andromeda::close(pnuData), add = TRUE)

  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  summary <- suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = list(makeDefaultAnalysis()),
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  expect_equal(summary$status[1], "OK")
})

test_that("runPnuAnalyses returns finite log_rr", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu(nSwitchers = 300L, logRr = log(2), seed = 6L)
  on.exit(Andromeda::close(pnuData), add = TRUE)

  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  summary <- suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = list(makeDefaultAnalysis()),
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  expect_true(is.finite(summary$log_rr[1]))
})

test_that("runPnuAnalyses result RDS has correct analysisId", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu(seed = 7L)
  on.exit(Andromeda::close(pnuData), add = TRUE)

  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = list(makeDefaultAnalysis(analysisId = 3L)),
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  result <- readRDS(file.path(outDir, "analysis_3.rds"))
  expect_equal(result$analysisId, 3L)
})

test_that("runPnuAnalyses matchedPop in RDS is a data frame with stratumId", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu(seed = 8L)
  on.exit(Andromeda::close(pnuData), add = TRUE)

  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = list(makeDefaultAnalysis()),
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  result <- readRDS(file.path(outDir, "analysis_1.rds"))
  expect_true(is.data.frame(result$matchedPop))
  expect_true("stratumId" %in% names(result$matchedPop))
})

test_that("runPnuAnalyses invisible return equals summary.csv contents", {
  skip_if_not_installed("Cyclops")
  pnuData <- makeSimPnu(seed = 9L)
  on.exit(Andromeda::close(pnuData), add = TRUE)

  outDir <- file.path(tempdir(), paste0("pnu_test_", sample.int(1e6, 1)))
  ret <- suppressMessages(
    runPnuAnalyses(
      pnuAnalysisList = list(makeDefaultAnalysis()),
      outputFolder    = outDir,
      pnuDataList     = list(pnuData)
    )
  )
  csv <- read.csv(file.path(outDir, "summary.csv"))
  expect_equal(ret$analysis_id, csv$analysis_id)
  expect_equal(ret$status, csv$status)
})
