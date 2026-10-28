# ---- helpers ----------------------------------------------------------------

makeMatchedNoConfounding <- function(nSwitchers = 500L,
                                     logRr = 0.0,
                                     seed = 1L) {
  simArgs <- createSimulationArgs(
    nSwitchers = nSwitchers,
    nComparatorsPerSet = nSwitchers,
    nExposureSets = 1L,
    nCovariates = 0L,
    outcomeBaseRate = 0.2,
    logRr = logRr,
    seed = seed
  )
  pnuData <- simulatePnuData(simArgs)
  spArgs <- createStudyPopulationArgs(outcomeId = 1L, requireTimeAtRisk = FALSE)
  pnuData <- createStudyPopulation(pnuData, spArgs)

  # With 0 covariates PS = 0.5 is correct; set it directly to avoid needing Cyclops for PS
  pop <- dplyr::collect(pnuData$studyPopulation)
  pop$propensityScore <- 0.5
  matched <- matchOnTcps(pop, createMatchingArgs(caliper = 0L))
  list(matched = matched, pnuData = pnuData)
}

# ---- createOutcomeModelArgs -------------------------------------------------

test_that("createOutcomeModelArgs validates modelType choices", {
  expect_error(createOutcomeModelArgs(modelType = "linear"))
})

test_that("createOutcomeModelArgs validates stratified is logical", {
  expect_error(createOutcomeModelArgs(stratified = "yes"))
})

test_that("createOutcomeModelArgs returns OutcomeModelArgs with correct defaults", {
  args <- createOutcomeModelArgs()
  expect_s3_class(args, "OutcomeModelArgs")
  expect_equal(args$modelType, "cox")
  expect_true(args$stratified)
  expect_false(args$useCovariates)
  expect_null(args$prior)
  expect_null(args$control)
})

test_that("createOutcomeModelArgs JSON round-trip preserves primitive fields", {
  original <- createOutcomeModelArgs(
    modelType = "logistic", stratified = FALSE, useCovariates = FALSE
  )
  restored <- OutcomeModelArgs$new(json = original$toJson())
  expect_equal(restored$modelType, "logistic")
  expect_false(restored$stratified)
})

test_that("OutcomeModelArgs toJson omits cyclopsPrior/cyclopsControl", {
  skip_if_not_installed("Cyclops")
  args <- createOutcomeModelArgs(
    prior = Cyclops::createPrior("normal", variance = 0.1)
  )
  json <- args$toJson()
  parsed <- jsonlite::fromJSON(json)
  expect_false("prior" %in% names(parsed))
  expect_true("modelType" %in% names(parsed))
})

# ---- fitOutcomeModel: structure ---------------------------------------------

test_that("fitOutcomeModel returns an OutcomeModel list with required fields", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding()
  on.exit(Andromeda::close(res$pnuData))

  result <- fitOutcomeModel(res$matched, res$pnuData, createOutcomeModelArgs())
  expect_true(inherits(result, "OutcomeModel"))
  expected <- c("logRr", "seLogRr", "p", "ci95Lb", "ci95Ub", "status")
  expect_true(all(expected %in% names(result)))
})

test_that("fitOutcomeModel status is OK when model fits successfully", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding()
  on.exit(Andromeda::close(res$pnuData))

  result <- fitOutcomeModel(res$matched, res$pnuData, createOutcomeModelArgs())
  expect_equal(result$status, "OK")
})

test_that("fitOutcomeModel returns finite numeric estimates when OK", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding()
  on.exit(Andromeda::close(res$pnuData))

  result <- fitOutcomeModel(res$matched, res$pnuData, createOutcomeModelArgs())
  expect_true(is.finite(result$logRr))
  expect_true(is.finite(result$seLogRr))
  expect_true(is.finite(result$p))
  expect_true(is.finite(result$ci95Lb))
  expect_true(is.finite(result$ci95Ub))
})

test_that("fitOutcomeModel CI bounds are ordered: ci95Lb < exp(logRr) < ci95Ub", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding()
  on.exit(Andromeda::close(res$pnuData))

  result <- fitOutcomeModel(res$matched, res$pnuData, createOutcomeModelArgs())
  expect_lt(result$ci95Lb, exp(result$logRr))
  expect_lt(exp(result$logRr), result$ci95Ub)
})

# ---- fitOutcomeModel: no-outcome cases --------------------------------------

test_that("fitOutcomeModel status describes problem when population is empty", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding()
  on.exit(Andromeda::close(res$pnuData))

  empty_pop <- res$matched[0L, ]
  result <- fitOutcomeModel(empty_pop, res$pnuData, createOutcomeModelArgs())
  expect_false(result$status == "OK")
})

test_that("fitOutcomeModel status describes problem when no outcomes present", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding()
  on.exit(Andromeda::close(res$pnuData))

  pop_no_outcomes <- res$matched
  pop_no_outcomes$outcome_count <- 0L
  result <- fitOutcomeModel(pop_no_outcomes, res$pnuData, createOutcomeModelArgs())
  expect_false(result$status == "OK")
})

# ---- fitOutcomeModel: statistical property ---------------------------------

test_that("fitOutcomeModel logRr within 2 SEs of log(2) with known true effect", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding(nSwitchers = 600L, logRr = log(2), seed = 2L)
  on.exit(Andromeda::close(res$pnuData))

  result <- fitOutcomeModel(res$matched, res$pnuData, createOutcomeModelArgs())
  expect_equal(result$status, "OK")
  expect_lt(abs(result$logRr - log(2)), 2 * result$seLogRr)
})

test_that("fitOutcomeModel logRr near 0 when true effect is null", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding(nSwitchers = 600L, logRr = 0.0, seed = 3L)
  on.exit(Andromeda::close(res$pnuData))

  result <- fitOutcomeModel(res$matched, res$pnuData, createOutcomeModelArgs())
  expect_equal(result$status, "OK")
  expect_lt(abs(result$logRr), 2 * result$seLogRr)
})

# ---- fitOutcomeModel: model types ------------------------------------------

test_that("fitOutcomeModel logistic stratified (clr) also returns OK", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding(nSwitchers = 400L, logRr = log(1.5), seed = 4L)
  on.exit(Andromeda::close(res$pnuData))

  args <- createOutcomeModelArgs(modelType = "logistic", stratified = TRUE)
  result <- fitOutcomeModel(res$matched, res$pnuData, args)
  expect_equal(result$status, "OK")
  expect_true(is.finite(result$logRr))
})

test_that("fitOutcomeModel unstratified cox returns OK", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding(nSwitchers = 400L, logRr = log(1.5), seed = 5L)
  on.exit(Andromeda::close(res$pnuData))

  args <- createOutcomeModelArgs(modelType = "cox", stratified = FALSE)
  result <- fitOutcomeModel(res$matched, res$pnuData, args)
  expect_equal(result$status, "OK")
  expect_true(is.finite(result$logRr))
})

# ---- fitOutcomeModel: error handling ----------------------------------------

test_that("fitOutcomeModel errors when stratified = TRUE but no stratumId", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding()
  on.exit(Andromeda::close(res$pnuData))

  pop_no_stratum <- res$matched
  pop_no_stratum$stratumId <- NULL
  expect_error(fitOutcomeModel(pop_no_stratum, res$pnuData, createOutcomeModelArgs()))
})

test_that("fitOutcomeModel errors when useCovariates = TRUE but pnuData is NULL", {
  skip_if_not_installed("Cyclops")
  res <- makeMatchedNoConfounding()
  on.exit(Andromeda::close(res$pnuData))

  args <- createOutcomeModelArgs(useCovariates = TRUE)
  expect_error(fitOutcomeModel(res$matched, NULL, args))
})

test_that("fitOutcomeModel errors on non-data-frame population", {
  skip_if_not_installed("Cyclops")
  expect_error(fitOutcomeModel(list(), NULL, createOutcomeModelArgs()))
})
