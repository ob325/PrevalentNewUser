# ---- helpers ----------------------------------------------------------------

# Compute AUC (Mann-Whitney C-statistic)
computeAuc <- function(treatment, propensityScore) {
  ps1 <- propensityScore[treatment == 1L]
  ps0 <- propensityScore[treatment == 0L]
  n1 <- length(ps1)
  n0 <- length(ps0)
  if (n1 == 0L || n0 == 0L) {
    return(NA_real_)
  }
  # Wilcoxon sum: for each switcher-comparator pair, count switcher > comparator
  u <- sum(outer(ps1, ps0, ">")) + 0.5 * sum(outer(ps1, ps0, "=="))
  u / (n1 * n0)
}

makePnuForTcps <- function(nSwitchers = 300L,
                           nComparators = 300L,
                           nExposureSets = 2L,
                           nCovariates = 5L,
                           prevalenceDiff = 0.3,
                           outcomeRate = 0.1,
                           seed = 1L) {
  simArgs <- createSimulationArgs(
    nSwitchers         = nSwitchers,
    nComparatorsPerSet = nComparators,
    nExposureSets      = nExposureSets,
    nCovariates        = nCovariates,
    prevalenceBase     = 0.2,
    prevalenceDiff     = prevalenceDiff,
    outcomeBaseRate    = outcomeRate,
    logRr              = 0.0,
    seed               = seed
  )
  pnuData <- simulatePnuData(simArgs)
  spArgs <- createStudyPopulationArgs(outcomeId = 1L, requireTimeAtRisk = FALSE)
  createStudyPopulation(pnuData, spArgs)
}

fastTcpsArgs <- function() {
  createTcpsArgs(
    prior   = Cyclops::createPrior("normal", variance = 0.1),
    control = Cyclops::createControl(noiseLevel = "silent")
  )
}

# ---- createTcpsArgs ---------------------------------------------------------

test_that("createTcpsArgs validates excludedCovariateConceptIds", {
  expect_error(createTcpsArgs(excludedCovariateConceptIds = c(-1L)))
})

test_that("createTcpsArgs validates maxCohortSizeForFitting >= 0", {
  expect_error(createTcpsArgs(maxCohortSizeForFitting = -1L))
})

test_that("createTcpsArgs returns a TcpsArgs object with correct defaults", {
  args <- createTcpsArgs()
  expect_s3_class(args, "TcpsArgs")
  expect_null(args$prior)
  expect_null(args$control)
  expect_equal(args$maxCohortSizeForFitting, 250000L)
  expect_equal(args$seed, 1L)
  expect_length(args$excludedCovariateConceptIds, 0L)
})

test_that("createTcpsArgs stores supplied Cyclops prior and control", {
  skip_if_not_installed("Cyclops")
  pr <- Cyclops::createPrior("normal", variance = 0.5)
  ctl <- Cyclops::createControl(noiseLevel = "silent")
  args <- createTcpsArgs(prior = pr, control = ctl)
  expect_true(inherits(args$prior, "cyclopsPrior"))
  expect_true(inherits(args$control, "cyclopsControl"))
})

test_that("TcpsArgs toJson omits cyclopsPrior/cyclopsControl fields", {
  skip_if_not_installed("Cyclops")
  args <- createTcpsArgs(
    prior = Cyclops::createPrior("normal", variance = 0.1),
    excludedCovariateConceptIds = c(1L, 2L)
  )
  json <- args$toJson()
  parsed <- jsonlite::fromJSON(json)
  # cyclopsPrior is omitted; NULL control is serialized; primitive fields present
  expect_false("prior" %in% names(parsed))
  expect_true("excludedCovariateConceptIds" %in% names(parsed))
  expect_equal(parsed$maxCohortSizeForFitting, 250000L)
})

# ---- fitTcps: structure -----------------------------------------------------

test_that("fitTcps returns a data frame with propensityScore column", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForTcps()
  on.exit(Andromeda::close(pnuData))

  pop <- dplyr::collect(pnuData$studyPopulation)
  tcpsArgs <- fastTcpsArgs()
  result <- fitTcps(pop, pnuData, tcpsArgs)

  expect_true(is.data.frame(result))
  expect_true("propensityScore" %in% names(result))
  expect_equal(nrow(result), nrow(pop))
})

test_that("fitTcps propensityScore is in [0, 1]", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForTcps()
  on.exit(Andromeda::close(pnuData))

  pop <- dplyr::collect(pnuData$studyPopulation)
  result <- fitTcps(pop, pnuData, fastTcpsArgs())

  ps <- result$propensityScore[!is.na(result$propensityScore)]
  expect_true(all(ps >= 0.0 & ps <= 1.0))
})

test_that("fitTcps works when nCovariates = 0 (sets PS = 0.5)", {
  skip_if_not_installed("Cyclops")
  simArgs <- createSimulationArgs(
    nSwitchers = 50L, nComparatorsPerSet = 50L, nExposureSets = 1L,
    nCovariates = 0L, seed = 2L
  )
  pnuData <- simulatePnuData(simArgs)
  spArgs <- createStudyPopulationArgs(outcomeId = 1L, requireTimeAtRisk = FALSE)
  pnuData <- createStudyPopulation(pnuData, spArgs)
  on.exit(Andromeda::close(pnuData))

  pop <- dplyr::collect(pnuData$studyPopulation)
  result <- suppressMessages(fitTcps(pop, pnuData, fastTcpsArgs()))

  expect_true(all(result$propensityScore == 0.5))
})

test_that("fitTcps respects excludedCovariateConceptIds (all covariates excluded)", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForTcps(nCovariates = 3L)
  on.exit(Andromeda::close(pnuData))

  pop <- dplyr::collect(pnuData$studyPopulation)
  # Exclude concept IDs 1, 2, 3 — all covariates
  tcpsArgs <- createTcpsArgs(
    prior = Cyclops::createPrior("normal", variance = 0.1),
    control = Cyclops::createControl(noiseLevel = "silent"),
    excludedCovariateConceptIds = c(1L, 2L, 3L)
  )
  result <- suppressMessages(fitTcps(pop, pnuData, tcpsArgs))
  expect_true(all(result$propensityScore == 0.5))
})

# ---- fitTcps: statistical property -----------------------------------------

test_that("fitTcps AUC > 0.6 with known covariate separation", {
  skip_if_not_installed("Cyclops")
  # Large sample, high prevalenceDiff → covariate clearly predicts switching
  pnuData <- makePnuForTcps(
    nSwitchers = 400L,
    nComparators = 400L,
    nExposureSets = 2L,
    nCovariates = 5L,
    prevalenceDiff = 0.4,
    seed = 10L
  )
  on.exit(Andromeda::close(pnuData))

  pop <- dplyr::collect(pnuData$studyPopulation)
  result <- fitTcps(pop, pnuData, fastTcpsArgs())

  auc <- computeAuc(result$treatment, result$propensityScore)
  expect_gt(auc, 0.6)
})

# ---- fitTcps: error handling ------------------------------------------------

test_that("fitTcps errors on non-data-frame population", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForTcps()
  on.exit(Andromeda::close(pnuData))
  expect_error(fitTcps(list(), pnuData, fastTcpsArgs()))
})

test_that("fitTcps errors on non-PnuData pnuData", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForTcps()
  on.exit(Andromeda::close(pnuData))
  pop <- dplyr::collect(pnuData$studyPopulation)
  expect_error(fitTcps(pop, list(), fastTcpsArgs()))
})

test_that("fitTcps errors on population missing required columns", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForTcps()
  on.exit(Andromeda::close(pnuData))
  pop_bad <- data.frame(x = 1:5) # missing row_id, exposure_set_id, treatment
  expect_error(fitTcps(pop_bad, pnuData, fastTcpsArgs()))
})
