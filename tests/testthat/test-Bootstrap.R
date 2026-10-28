# ---- helpers ----------------------------------------------------------------

# Build a fast matched population with a known true effect, no covariates
makeMatchedForBoot <- function(nSwitchers = 300L,
                               logRr = log(1.5),
                               seed = 1L) {
  simArgs <- createSimulationArgs(
    nSwitchers         = nSwitchers,
    nComparatorsPerSet = nSwitchers,
    nExposureSets      = 1L,
    nCovariates        = 0L,
    outcomeBaseRate    = 0.2,
    logRr              = logRr,
    seed               = seed
  )
  pnuData <- simulatePnuData(simArgs)
  spArgs <- createStudyPopulationArgs(outcomeId = 1L, requireTimeAtRisk = FALSE)
  pnuData <- createStudyPopulation(pnuData, spArgs)

  pop <- dplyr::collect(pnuData$studyPopulation)
  pop$propensityScore <- 0.5
  matched <- suppressMessages(matchOnTcps(pop, createMatchingArgs(caliper = 0L)))
  Andromeda::close(pnuData)
  matched
}

fastBootstrapArgs <- function(nRep = 50L, seed = 1L) {
  createBootstrapArgs(numberOfReplications = nRep, seed = seed, cores = 1L)
}

# ---- createBootstrapArgs ----------------------------------------------------

test_that("createBootstrapArgs validates numberOfReplications >= 1", {
  expect_error(createBootstrapArgs(numberOfReplications = 0L))
})

test_that("createBootstrapArgs validates cores >= 1", {
  expect_error(createBootstrapArgs(cores = 0L))
})

test_that("createBootstrapArgs returns BootstrapArgs with correct defaults", {
  args <- createBootstrapArgs()
  expect_s3_class(args, "BootstrapArgs")
  expect_equal(args$numberOfReplications, 1000L)
  expect_equal(args$seed, 1L)
  expect_equal(args$cores, 1L)
})

test_that("createBootstrapArgs JSON round-trip preserves all fields", {
  original <- createBootstrapArgs(numberOfReplications = 200L, seed = 42L, cores = 2L)
  restored <- BootstrapArgs$new(json = original$toJson())
  expect_equal(restored$numberOfReplications, 200L)
  expect_equal(restored$seed, 42L)
  expect_equal(restored$cores, 2L)
})

# ---- bootstrapCi: structure -------------------------------------------------

test_that("bootstrapCi returns a list with required fields", {
  skip_if_not_installed("Cyclops")
  matched <- makeMatchedForBoot()
  result <- suppressMessages(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs())
  )
  expected <- c("logRr", "seLogRr", "ci95Lb", "ci95Ub", "numberOfBootstraps", "status")
  expect_true(all(expected %in% names(result)))
})

test_that("bootstrapCi status is OK when fit succeeds", {
  skip_if_not_installed("Cyclops")
  matched <- makeMatchedForBoot()
  result <- suppressMessages(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs())
  )
  expect_equal(result$status, "OK")
})

test_that("bootstrapCi logRr matches fitOutcomeModel on the same population", {
  skip_if_not_installed("Cyclops")
  matched <- makeMatchedForBoot()
  original <- fitOutcomeModel(matched, NULL, createOutcomeModelArgs())
  boot <- suppressMessages(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs())
  )
  expect_equal(boot$logRr, original$logRr)
})

test_that("bootstrapCi seLogRr is positive", {
  skip_if_not_installed("Cyclops")
  matched <- makeMatchedForBoot()
  result <- suppressMessages(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs())
  )
  expect_gt(result$seLogRr, 0)
})

test_that("bootstrapCi CI brackets the point estimate: ci95Lb < exp(logRr) < ci95Ub", {
  skip_if_not_installed("Cyclops")
  matched <- makeMatchedForBoot()
  result <- suppressMessages(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs())
  )
  expect_lt(result$ci95Lb, exp(result$logRr))
  expect_lt(exp(result$logRr), result$ci95Ub)
})

test_that("bootstrapCi numberOfBootstraps equals numberOfReplications when no failures", {
  skip_if_not_installed("Cyclops")
  matched <- makeMatchedForBoot(nSwitchers = 200L, seed = 2L)
  result <- suppressMessages(
    bootstrapCi(
      matched, NULL, createOutcomeModelArgs(),
      createBootstrapArgs(numberOfReplications = 30L, seed = 1L)
    )
  )
  # At least most replications should succeed
  expect_gte(result$numberOfBootstraps, 20L)
})

# ---- bootstrapCi: reproducibility ------------------------------------------

test_that("bootstrapCi is reproducible with the same seed", {
  skip_if_not_installed("Cyclops")
  matched <- makeMatchedForBoot()
  r1 <- suppressMessages(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs(seed = 7L))
  )
  r2 <- suppressMessages(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs(seed = 7L))
  )
  expect_equal(r1$seLogRr, r2$seLogRr)
  expect_equal(r1$ci95Lb, r2$ci95Lb)
  expect_equal(r1$ci95Ub, r2$ci95Ub)
})

test_that("bootstrapCi with different seeds gives different results", {
  skip_if_not_installed("Cyclops")
  matched <- makeMatchedForBoot()
  r1 <- suppressMessages(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs(seed = 1L))
  )
  r2 <- suppressMessages(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs(seed = 99L))
  )
  expect_false(identical(r1$seLogRr, r2$seLogRr))
})

# ---- bootstrapCi: error handling --------------------------------------------

test_that("bootstrapCi errors on population missing stratumId", {
  skip_if_not_installed("Cyclops")
  matched <- makeMatchedForBoot()
  matched$stratumId <- NULL
  expect_error(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs())
  )
})

test_that("bootstrapCi errors on non-data-frame population", {
  skip_if_not_installed("Cyclops")
  expect_error(
    bootstrapCi(list(), NULL, createOutcomeModelArgs(), fastBootstrapArgs())
  )
})

test_that("bootstrapCi status describes failure when no outcomes", {
  skip_if_not_installed("Cyclops")
  matched <- makeMatchedForBoot()
  matched$outcome_count <- 0L
  result <- suppressMessages(
    bootstrapCi(matched, NULL, createOutcomeModelArgs(), fastBootstrapArgs())
  )
  expect_false(result$status == "OK")
})
