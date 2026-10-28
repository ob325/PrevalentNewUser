test_that("createPnuCohortArgs returns a PnuCohortArgs object with correct fields", {
  args <- createPnuCohortArgs(
    targetCohortId = 1,
    comparatorCohortId = 2,
    outcomeCohortId = 3
  )
  expect_s3_class(args, "PnuCohortArgs")
  expect_s3_class(args, "R6")
  expect_equal(args$targetCohortId, 1L)
  expect_equal(args$comparatorCohortId, 2L)
  expect_equal(args$outcomeCohortId, 3L)
  expect_equal(args$excludedCovariateConceptIds, integer(0))
  expect_equal(args$includedCovariateConceptIds, integer(0))
  expect_equal(args$washoutPeriod, 365L)
  expect_equal(args$maxCohortSize, 0L)
})

test_that("createPnuCohortArgs stores concept ID vectors as integers", {
  args <- createPnuCohortArgs(
    targetCohortId = 10,
    comparatorCohortId = 20,
    outcomeCohortId = 30,
    excludedCovariateConceptIds = c(100, 200),
    includedCovariateConceptIds = c(300)
  )
  expect_type(args$excludedCovariateConceptIds, "integer")
  expect_type(args$includedCovariateConceptIds, "integer")
  expect_equal(args$excludedCovariateConceptIds, c(100L, 200L))
  expect_equal(args$includedCovariateConceptIds, c(300L))
})

test_that("createPnuCohortArgs round-trips through JSON", {
  args <- createPnuCohortArgs(
    targetCohortId = 5,
    comparatorCohortId = 6,
    outcomeCohortId = 7,
    excludedCovariateConceptIds = c(10L, 20L),
    washoutPeriod = 180,
    maxCohortSize = 5000
  )
  json <- args$toJson()
  expect_type(json, "character")
  expect_true(nchar(json) > 0)

  args2 <- PnuCohortArgs$new(json = json)
  expect_equal(args2$targetCohortId, args$targetCohortId)
  expect_equal(args2$comparatorCohortId, args$comparatorCohortId)
  expect_equal(args2$outcomeCohortId, args$outcomeCohortId)
  expect_equal(args2$excludedCovariateConceptIds, args$excludedCovariateConceptIds)
  expect_equal(args2$washoutPeriod, args$washoutPeriod)
  expect_equal(args2$maxCohortSize, args$maxCohortSize)
})

test_that("createPnuCohortArgs errors on missing required cohort IDs", {
  expect_error(createPnuCohortArgs(comparatorCohortId = 2, outcomeCohortId = 3))
  expect_error(createPnuCohortArgs(targetCohortId = 1, outcomeCohortId = 3))
  expect_error(createPnuCohortArgs(targetCohortId = 1, comparatorCohortId = 2))
})

test_that("createPnuCohortArgs errors on non-positive cohort IDs", {
  expect_error(createPnuCohortArgs(targetCohortId = 0, comparatorCohortId = 2, outcomeCohortId = 3))
  expect_error(createPnuCohortArgs(targetCohortId = -1, comparatorCohortId = 2, outcomeCohortId = 3))
})

test_that("createPnuCohortArgs errors on negative washoutPeriod or maxCohortSize", {
  expect_error(
    createPnuCohortArgs(
      targetCohortId = 1, comparatorCohortId = 2, outcomeCohortId = 3,
      washoutPeriod = -1
    )
  )
  expect_error(
    createPnuCohortArgs(
      targetCohortId = 1, comparatorCohortId = 2, outcomeCohortId = 3,
      maxCohortSize = -5
    )
  )
})

test_that("PnuCohortArgs$validate() passes on a valid object", {
  args <- createPnuCohortArgs(
    targetCohortId = 1,
    comparatorCohortId = 2,
    outcomeCohortId = 3
  )
  expect_silent(args$validate())
})

test_that("PnuCohortArgs$validate() errors when required fields are NULL", {
  args <- PnuCohortArgs$new()
  expect_error(args$validate())
})
