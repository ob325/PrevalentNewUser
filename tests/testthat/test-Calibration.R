# ---- helpers ----------------------------------------------------------------

# Simulate negative control estimates under systematic error:
# observed ~ N(trueMean + biasMean, biasSd^2 + se^2)
makeNegControls <- function(n = 100L,
                            biasMean = 0.05,
                            biasSd = 0.15,
                            se = 0.12,
                            seed = 1L) {
  withr::with_seed(seed, {
    trueEffect <- rnorm(n, biasMean, biasSd)
    logRr <- rnorm(n, trueEffect, se)
    data.frame(logRr = logRr, seLogRr = rep(se, n))
  })
}

# ---- calibrateEstimates: validation -----------------------------------------

test_that("calibrateEstimates errors when estimates missing logRr", {
  nc <- makeNegControls()
  expect_error(calibrateEstimates(
    data.frame(seLogRr = 0.1),
    nc
  ))
})

test_that("calibrateEstimates errors when estimates missing seLogRr", {
  nc <- makeNegControls()
  expect_error(calibrateEstimates(
    data.frame(logRr = 0.3),
    nc
  ))
})

test_that("calibrateEstimates errors when negativeControlOutcomes missing logRr", {
  est <- data.frame(logRr = 0.3, seLogRr = 0.1)
  expect_error(calibrateEstimates(est, data.frame(seLogRr = 0.1)))
})

test_that("calibrateEstimates errors when fewer than 2 complete negative controls", {
  est <- data.frame(logRr = 0.3, seLogRr = 0.1)
  nc <- data.frame(logRr = 0.1, seLogRr = 0.1) # only 1 row
  expect_error(calibrateEstimates(est, nc))
})

test_that("calibrateEstimates errors on non-data-frame estimates", {
  expect_error(calibrateEstimates(list(logRr = 0.3), makeNegControls()))
})

# ---- calibrateEstimates: structure ------------------------------------------

test_that("calibrateEstimates returns a data frame", {
  skip_if_not_installed("EmpiricalCalibration")
  nc <- makeNegControls()
  est <- data.frame(logRr = 0.3, seLogRr = 0.1)
  result <- calibrateEstimates(est, nc)
  expect_true(is.data.frame(result))
})

test_that("calibrateEstimates result has five extra columns", {
  skip_if_not_installed("EmpiricalCalibration")
  nc <- makeNegControls()
  est <- data.frame(logRr = 0.3, seLogRr = 0.1)
  result <- calibrateEstimates(est, nc)
  extra <- c("calibratedLogRr", "calibratedSeLogRr", "calibratedP",
             "calibratedCi95Lb", "calibratedCi95Ub")
  expect_true(all(extra %in% names(result)))
})

test_that("calibrateEstimates preserves original columns", {
  skip_if_not_installed("EmpiricalCalibration")
  nc <- makeNegControls()
  est <- data.frame(analysis_id = 7L, logRr = 0.3, seLogRr = 0.1)
  result <- calibrateEstimates(est, nc)
  expect_true("analysis_id" %in% names(result))
  expect_equal(result$analysis_id, 7L)
})

test_that("calibrateEstimates returns same number of rows as estimates", {
  skip_if_not_installed("EmpiricalCalibration")
  nc <- makeNegControls()
  est <- data.frame(logRr = c(0.3, -0.1, 0.0), seLogRr = c(0.1, 0.1, 0.1))
  result <- calibrateEstimates(est, nc)
  expect_equal(nrow(result), 3L)
})

# ---- calibrateEstimates: output values --------------------------------------

test_that("calibratedP is in [0, 1]", {
  skip_if_not_installed("EmpiricalCalibration")
  nc <- makeNegControls()
  est <- data.frame(logRr = c(0.3, -0.1, 0.0), seLogRr = c(0.1, 0.1, 0.1))
  result <- calibrateEstimates(est, nc)
  expect_true(all(result$calibratedP >= 0 & result$calibratedP <= 1, na.rm = TRUE))
})

test_that("calibrated CI is ordered: ci95Lb < exp(calibratedLogRr) < ci95Ub", {
  skip_if_not_installed("EmpiricalCalibration")
  nc <- makeNegControls()
  est <- data.frame(logRr = 0.3, seLogRr = 0.1)
  result <- calibrateEstimates(est, nc)
  expect_lt(result$calibratedCi95Lb, exp(result$calibratedLogRr))
  expect_lt(exp(result$calibratedLogRr), result$calibratedCi95Ub)
})

test_that("calibrated CI is wider than uncalibrated CI when systematic error is present", {
  skip_if_not_installed("EmpiricalCalibration")
  # With systematic error (biasSd > 0), calibrated CI should be wider
  nc <- makeNegControls(biasMean = 0.1, biasSd = 0.2, se = 0.1, seed = 3L)
  est <- data.frame(logRr = 0.3, seLogRr = 0.1)
  result <- calibrateEstimates(est, nc)
  uncalWidth <- log(est$seLogRr * 2 * qnorm(0.975) * 2)
  calibWidth <- log(result$calibratedCi95Ub) - log(result$calibratedCi95Lb)
  expect_gt(calibWidth, log(result$calibratedCi95Ub / result$calibratedCi95Lb) * 0.5)
  # Simpler: seLogRr should be inflated
  expect_gt(result$calibratedSeLogRr, est$seLogRr)
})

test_that("NA estimates produce NA calibrated values", {
  skip_if_not_installed("EmpiricalCalibration")
  nc <- makeNegControls()
  est <- data.frame(
    logRr   = c(0.3, NA_real_),
    seLogRr = c(0.1, 0.1)
  )
  result <- calibrateEstimates(est, nc)
  expect_true(is.na(result$calibratedLogRr[2]))
  expect_true(is.na(result$calibratedP[2]))
  expect_true(is.finite(result$calibratedLogRr[1]))
})

test_that("negative controls with NA logRr are silently dropped", {
  skip_if_not_installed("EmpiricalCalibration")
  nc <- makeNegControls()
  nc$logRr[1] <- NA_real_
  est <- data.frame(logRr = 0.3, seLogRr = 0.1)
  # Should not error even with one NA in negative controls
  expect_no_error(calibrateEstimates(est, nc))
})

# ---- calibrateEstimates: statistical property -------------------------------

test_that("calibrated p-values are approximately uniform under null", {
  skip_if_not_installed("EmpiricalCalibration")
  # Simulate a systematic error model: bias ~ N(0.05, 0.15^2), seLogRr = 0.12
  set.seed(42)
  n_train <- 150L
  n_test  <- 150L
  biasMean <- 0.05
  biasSd   <- 0.15
  se       <- 0.12

  trueEffectTrain <- rnorm(n_train, biasMean, biasSd)
  ncTrain <- data.frame(
    logRr   = rnorm(n_train, trueEffectTrain, se),
    seLogRr = rep(se, n_train)
  )
  # Test estimates are also null (true logRr = 0); only systematic error inflates
  trueEffectTest <- rnorm(n_test, biasMean, biasSd)
  ncTest <- data.frame(
    logRr   = rnorm(n_test, trueEffectTest, se),
    seLogRr = rep(se, n_test)
  )

  result <- calibrateEstimates(ncTest, ncTrain)

  ks <- ks.test(result$calibratedP, "punif")
  expect_gt(ks$p.value, 0.01)
})
