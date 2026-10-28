# ---- helpers ----------------------------------------------------------------

makePnuForBalance <- function(nSwitchers = 300L,
                              nComparators = 300L,
                              nCovariates = 5L,
                              prevalenceDiff = 0.3,
                              seed = 1L) {
  simArgs <- createSimulationArgs(
    nSwitchers = nSwitchers,
    nComparatorsPerSet = nComparators,
    nExposureSets = 1L,
    nCovariates = nCovariates,
    prevalenceBase = 0.3,
    prevalenceDiff = prevalenceDiff,
    outcomeBaseRate = 0.1,
    logRr = 0.0,
    seed = seed
  )
  pnuData <- simulatePnuData(simArgs)
  spArgs <- createStudyPopulationArgs(outcomeId = 1L, requireTimeAtRisk = FALSE)
  createStudyPopulation(pnuData, spArgs)
}

makeMatchedPop <- function(pnuData, seed = 1L) {
  skip_if_not_installed("Cyclops")
  pop <- dplyr::collect(pnuData$studyPopulation)
  tcpsArgs <- createTcpsArgs(
    prior = Cyclops::createPrior("normal", variance = 0.1),
    control = Cyclops::createControl(noiseLevel = "silent"),
    seed = seed
  )
  pop <- fitTcps(pop, pnuData, tcpsArgs)
  matchOnTcps(pop, createMatchingArgs(caliper = 0.2, maxRatio = 1L))
}

# ---- createBalanceArgs ------------------------------------------------------

test_that("createBalanceArgs validates maxCohortSizeForBalance >= 0", {
  expect_error(createBalanceArgs(maxCohortSizeForBalance = -1L))
})

test_that("createBalanceArgs returns a BalanceArgs with correct default", {
  args <- createBalanceArgs()
  expect_s3_class(args, "BalanceArgs")
  expect_equal(args$maxCohortSizeForBalance, 250000L)
})

test_that("createBalanceArgs JSON round-trip preserves fields", {
  original <- createBalanceArgs(maxCohortSizeForBalance = 10000L)
  restored <- BalanceArgs$new(json = original$toJson())
  expect_equal(restored$maxCohortSizeForBalance, 10000L)
})

# ---- computeCovariateBalance: structure -------------------------------------

test_that("computeCovariateBalance returns a tibble with required columns", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForBalance()
  on.exit(Andromeda::close(pnuData))

  matched <- makeMatchedPop(pnuData)
  result <- computeCovariateBalance(matched, pnuData, createBalanceArgs())

  expect_true(is.data.frame(result))
  expected_cols <- c(
    "covariate_id", "covariate_name",
    "beforeMatchingMeanTarget", "beforeMatchingMeanComparator", "beforeMatchingSmd",
    "afterMatchingMeanTarget", "afterMatchingMeanComparator", "afterMatchingSmd"
  )
  expect_true(all(expected_cols %in% names(result)))
})

test_that("computeCovariateBalance returns one row per covariate", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForBalance(nCovariates = 5L)
  on.exit(Andromeda::close(pnuData))

  matched <- makeMatchedPop(pnuData)
  result <- computeCovariateBalance(matched, pnuData, createBalanceArgs())

  expect_equal(nrow(result), 5L)
  expect_equal(length(unique(result$covariate_id)), 5L)
})

test_that("computeCovariateBalance covariate_name is non-NA", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForBalance(nCovariates = 3L)
  on.exit(Andromeda::close(pnuData))

  matched <- makeMatchedPop(pnuData)
  result <- computeCovariateBalance(matched, pnuData, createBalanceArgs())

  expect_false(any(is.na(result$covariate_name)))
})

test_that("computeCovariateBalance means are in [0, 1] for binary covariates", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForBalance()
  on.exit(Andromeda::close(pnuData))

  matched <- makeMatchedPop(pnuData)
  result <- computeCovariateBalance(matched, pnuData, createBalanceArgs())

  expect_true(all(result$beforeMatchingMeanTarget >= 0 & result$beforeMatchingMeanTarget <= 1))
  expect_true(all(result$beforeMatchingMeanComparator >= 0 & result$beforeMatchingMeanComparator <= 1))
  expect_true(all(result$afterMatchingMeanTarget >= 0 & result$afterMatchingMeanTarget <= 1))
  expect_true(all(result$afterMatchingMeanComparator >= 0 & result$afterMatchingMeanComparator <= 1))
})

test_that("computeCovariateBalance sorted by descending |beforeMatchingSmd|", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForBalance(nCovariates = 5L, seed = 2L)
  on.exit(Andromeda::close(pnuData))

  matched <- makeMatchedPop(pnuData)
  result <- computeCovariateBalance(matched, pnuData, createBalanceArgs())

  absSmd <- abs(result$beforeMatchingSmd)
  expect_true(all(diff(absSmd) <= 0))
})

# ---- computeCovariateBalance: statistical property --------------------------

test_that("afterMatchingSmd smaller than beforeMatchingSmd after matching on PS", {
  skip_if_not_installed("Cyclops")
  # Large prevalence difference → strong covariate imbalance before matching
  pnuData <- makePnuForBalance(
    nSwitchers = 500L, nComparators = 500L,
    nCovariates = 1L, prevalenceDiff = 0.4, seed = 3L
  )
  on.exit(Andromeda::close(pnuData))

  matched <- makeMatchedPop(pnuData, seed = 3L)
  result <- computeCovariateBalance(matched, pnuData, createBalanceArgs())

  expect_lt(abs(result$afterMatchingSmd[1L]), abs(result$beforeMatchingSmd[1L]))
})

test_that("|afterMatchingSmd| < 0.1 after matching with known covariate separation", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForBalance(
    nSwitchers = 600L, nComparators = 600L,
    nCovariates = 1L, prevalenceDiff = 0.4, seed = 4L
  )
  on.exit(Andromeda::close(pnuData))

  matched <- makeMatchedPop(pnuData, seed = 4L)
  result <- computeCovariateBalance(matched, pnuData, createBalanceArgs())

  expect_lt(abs(result$afterMatchingSmd[1L]), 0.1)
})

# ---- computeCovariateBalance: error handling --------------------------------

test_that("computeCovariateBalance errors on population missing stratumId", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForBalance(nCovariates = 2L)
  on.exit(Andromeda::close(pnuData))

  pop_no_stratum <- dplyr::collect(pnuData$studyPopulation)
  expect_error(computeCovariateBalance(pop_no_stratum, pnuData, createBalanceArgs()))
})

test_that("computeCovariateBalance errors on non-PnuData pnuData", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForBalance(nCovariates = 2L)
  on.exit(Andromeda::close(pnuData))

  matched <- makeMatchedPop(pnuData)
  expect_error(computeCovariateBalance(matched, list(), createBalanceArgs()))
})

test_that("computeCovariateBalance errors on non-BalanceArgs balanceArgs", {
  skip_if_not_installed("Cyclops")
  pnuData <- makePnuForBalance(nCovariates = 2L)
  on.exit(Andromeda::close(pnuData))

  matched <- makeMatchedPop(pnuData)
  expect_error(computeCovariateBalance(matched, pnuData, list()))
})
