# ---- createSimulationArgs ---------------------------------------------------

test_that("createSimulationArgs validates nSwitchers >= 1", {
  expect_error(createSimulationArgs(nSwitchers = 0L))
})

test_that("createSimulationArgs validates nCovariates >= 0", {
  expect_error(createSimulationArgs(nCovariates = -1L))
})

test_that("createSimulationArgs validates prevalenceBase in [0, 1]", {
  expect_error(createSimulationArgs(prevalenceBase = 1.5))
  expect_error(createSimulationArgs(prevalenceBase = -0.1))
})

test_that("createSimulationArgs returns a SimulationArgs object", {
  args <- createSimulationArgs(nSwitchers = 50L, logRr = log(2), seed = 7L)
  expect_s3_class(args, "SimulationArgs")
  expect_equal(args$nSwitchers, 50L)
  expect_equal(args$logRr, log(2))
  expect_equal(args$seed, 7L)
})

test_that("createSimulationArgs JSON round-trip preserves all fields", {
  original <- createSimulationArgs(
    nSwitchers = 75L, nComparatorsPerSet = 100L, nExposureSets = 2L,
    nCovariates = 4L, prevalenceBase = 0.3, prevalenceDiff = 0.05,
    outcomeBaseRate = 0.08, followUpDays = 180L, logRr = log(1.5), seed = 12L
  )
  json <- original$toJson()
  restored <- createSimulationArgs(json = json)
  expect_equal(restored$nSwitchers, 75L)
  expect_equal(restored$nComparatorsPerSet, 100L)
  expect_equal(restored$nExposureSets, 2L)
  expect_equal(restored$nCovariates, 4L)
  expect_equal(restored$prevalenceBase, 0.3)
  expect_equal(restored$prevalenceDiff, 0.05)
  expect_equal(restored$outcomeBaseRate, 0.08)
  expect_equal(restored$followUpDays, 180L)
  expect_equal(restored$logRr, log(1.5))
  expect_equal(restored$seed, 12L)
})

# ---- simulatePnuData: structure ---------------------------------------------

test_that("simulatePnuData returns a valid PnuData", {
  simArgs <- createSimulationArgs(
    nSwitchers = 100L, nComparatorsPerSet = 80L,
    nExposureSets = 2L, nCovariates = 5L, seed = 1L
  )
  result <- simulatePnuData(simArgs)
  on.exit(Andromeda::close(result))

  expect_true(isPnuData(result))
})

test_that("simulatePnuData cohorts table has correct row counts", {
  simArgs <- createSimulationArgs(
    nSwitchers = 100L, nComparatorsPerSet = 80L,
    nExposureSets = 2L, nCovariates = 0L, seed = 1L
  )
  result <- simulatePnuData(simArgs)
  on.exit(Andromeda::close(result))

  cohorts <- dplyr::collect(result$cohorts)
  expect_equal(nrow(cohorts), 360L) # 2 × (100 + 80)
  expect_equal(sum(cohorts$treatment == 1L), 200L) # 2 × 100 switchers
  expect_equal(sum(cohorts$treatment == 0L), 160L) # 2 × 80 comparators
  expect_setequal(cohorts$exposure_set_id, 1:2)
  expect_equal(dplyr::n_distinct(cohorts$row_id), 360L)
  expect_equal(dplyr::n_distinct(cohorts$person_seq_id), 360L)
})

test_that("simulatePnuData outcomes are on or before cohort_end_date", {
  simArgs <- createSimulationArgs(
    nSwitchers = 200L, nComparatorsPerSet = 200L,
    nExposureSets = 1L, nCovariates = 0L,
    outcomeBaseRate = 0.3, seed = 2L
  )
  result <- simulatePnuData(simArgs)
  on.exit(Andromeda::close(result))

  cohorts <- dplyr::collect(result$cohorts)
  outcomes <- dplyr::collect(result$outcomes)

  expect_true(nrow(outcomes) > 0L)

  merged <- dplyr::inner_join(
    outcomes,
    dplyr::select(cohorts, "person_seq_id", "cohort_start_date", "cohort_end_date"),
    by = "person_seq_id"
  )
  expect_true(all(merged$outcome_date >= merged$cohort_start_date))
  expect_true(all(merged$outcome_date < merged$cohort_end_date))
})

test_that("simulatePnuData covariateRef has nCovariates rows", {
  simArgs <- createSimulationArgs(
    nSwitchers = 50L, nComparatorsPerSet = 50L,
    nExposureSets = 1L, nCovariates = 7L, seed = 3L
  )
  result <- simulatePnuData(simArgs)
  on.exit(Andromeda::close(result))

  covRef <- dplyr::collect(result$covariateRef)
  expect_equal(nrow(covRef), 7L)
  expect_setequal(covRef$covariate_id, as.numeric(1:7))
})

test_that("simulatePnuData with nCovariates = 0 produces empty covariate tables", {
  simArgs <- createSimulationArgs(
    nSwitchers = 50L, nComparatorsPerSet = 50L,
    nExposureSets = 1L, nCovariates = 0L, seed = 4L
  )
  result <- simulatePnuData(simArgs)
  on.exit(Andromeda::close(result))

  expect_equal(dplyr::collect(result$covariates) |> nrow(), 0L)
  expect_equal(dplyr::collect(result$covariateRef) |> nrow(), 0L)
  expect_equal(dplyr::collect(result$analysisRef) |> nrow(), 0L)
})

test_that("simulatePnuData exposureSets table is consistent with cohorts", {
  simArgs <- createSimulationArgs(
    nSwitchers = 60L, nComparatorsPerSet = 60L,
    nExposureSets = 3L, nCovariates = 0L, seed = 5L
  )
  result <- simulatePnuData(simArgs)
  on.exit(Andromeda::close(result))

  cohorts <- dplyr::collect(result$cohorts)
  esets <- dplyr::collect(result$exposureSets)

  expect_equal(nrow(esets), nrow(cohorts))
  expect_setequal(esets$person_seq_id, cohorts$person_seq_id)
  expect_equal(dplyr::n_distinct(esets$exposure_set_id), 3L)
  # days_on_a = set_id * 30
  expect_true(all(esets$days_on_a == esets$exposure_set_id * 30L))
})

test_that("simulatePnuData metaData contains simulationArgs JSON", {
  simArgs <- createSimulationArgs(nSwitchers = 30L, seed = 6L)
  result <- simulatePnuData(simArgs)
  on.exit(Andromeda::close(result))

  md <- attr(result, "metaData")
  expect_false(is.null(md$simulationArgs))
  expect_type(md$simulationArgs, "character")
})

# ---- simulatePnuData: reproducibility ---------------------------------------

test_that("simulatePnuData is reproducible with the same seed", {
  simArgs <- createSimulationArgs(
    nSwitchers = 50L, nComparatorsPerSet = 50L,
    nExposureSets = 2L, nCovariates = 3L, seed = 99L
  )
  r1 <- simulatePnuData(simArgs)
  r2 <- simulatePnuData(simArgs)
  on.exit({
    Andromeda::close(r1)
    Andromeda::close(r2)
  })

  outcomes1 <- dplyr::collect(r1$outcomes)
  outcomes2 <- dplyr::collect(r2$outcomes)
  expect_identical(outcomes1, outcomes2)

  covs1 <- dplyr::collect(r1$covariates) |> dplyr::arrange(.data$row_id, .data$covariate_id)
  covs2 <- dplyr::collect(r2$covariates) |> dplyr::arrange(.data$row_id, .data$covariate_id)
  expect_identical(covs1, covs2)
})

test_that("simulatePnuData does not alter the caller's RNG state", {
  set.seed(123L)
  x1 <- stats::runif(5)

  set.seed(123L)
  simArgs <- createSimulationArgs(nSwitchers = 50L, seed = 7L)
  result <- simulatePnuData(simArgs)
  Andromeda::close(result)
  x2 <- stats::runif(5)

  expect_identical(x1, x2)
})

# ---- simulatePnuData: statistical properties --------------------------------

test_that("simulatePnuData with logRr = 0 gives crude rate ratio near 1.0", {
  simArgs <- createSimulationArgs(
    nSwitchers         = 3000L,
    nComparatorsPerSet = 3000L,
    nExposureSets      = 1L,
    nCovariates        = 0L,
    prevalenceDiff     = 0.0,
    outcomeBaseRate    = 0.15,
    logRr              = 0.0,
    seed               = 42L
  )
  result <- simulatePnuData(simArgs)
  on.exit(Andromeda::close(result))

  cohorts <- dplyr::collect(result$cohorts)
  outcomes <- dplyr::collect(result$outcomes)

  switchIds <- cohorts$person_seq_id[cohorts$treatment == 1L]
  compareIds <- cohorts$person_seq_id[cohorts$treatment == 0L]

  nEventSwitch <- sum(outcomes$person_seq_id %in% switchIds)
  nEventCompare <- sum(outcomes$person_seq_id %in% compareIds)

  rateSwitch <- nEventSwitch / length(switchIds)
  rateCompare <- nEventCompare / length(compareIds)

  crudeRr <- rateSwitch / rateCompare

  # With 3000 per arm and 15% baseline rate, SE(log RR) ≈ 0.067
  # A 20% bound corresponds to ~3 SD: expected to pass for virtually any seed
  expect_gt(crudeRr, 0.80)
  expect_lt(crudeRr, 1.20)
})
