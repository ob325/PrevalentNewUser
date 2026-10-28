test_that("createEmptyPnuData returns a PnuData object", {
  pd <- createEmptyPnuData()
  on.exit(Andromeda::close(pd))

  expect_true(isPnuData(pd))
  expect_s4_class(pd, "PnuData")
  expect_s4_class(pd, "CovariateData")
})

test_that("isPnuData returns FALSE for non-PnuData objects", {
  expect_false(isPnuData(list()))
  expect_false(isPnuData(NULL))
  expect_false(isPnuData(data.frame()))
  expect_false(isPnuData(1L))
})

test_that("createEmptyPnuData has the expected tables", {
  pd <- createEmptyPnuData()
  on.exit(Andromeda::close(pd))

  expect_true(!is.null(pd$cohorts))
  expect_true(!is.null(pd$outcomes))
  expect_true(!is.null(pd$exposureSets))
  expect_true(!is.null(pd$covariates))
  expect_true(!is.null(pd$covariateRef))
  expect_true(!is.null(pd$analysisRef))
})

test_that("createEmptyPnuData tables have the expected columns", {
  pd <- createEmptyPnuData()
  on.exit(Andromeda::close(pd))

  cohortCols <- colnames(dplyr::collect(pd$cohorts))
  expect_true(all(c("row_id", "person_seq_id", "person_id",
                    "cohort_start_date", "cohort_end_date",
                    "treatment", "exposure_set_id") %in% cohortCols))

  outcomeCols <- colnames(dplyr::collect(pd$outcomes))
  expect_true(all(c("person_seq_id", "outcome_id", "outcome_date") %in% outcomeCols))

  setsCols <- colnames(dplyr::collect(pd$exposureSets))
  expect_true(all(c("person_seq_id", "exposure_set_id", "days_on_a") %in% setsCols))
})

test_that("summary.PnuData returns the correct counts on an empty object", {
  pd <- createEmptyPnuData()
  on.exit(Andromeda::close(pd))

  s <- summary(pd)
  expect_s3_class(s, "summary.PnuData")
  expect_equal(s$switcherCount, 0L)
  expect_equal(s$comparatorCount, 0L)
  expect_equal(s$exposureSetCount, 0L)
  expect_equal(s$outcomeCount, 0L)
  expect_equal(s$covariateCount, 0L)
  expect_equal(s$covariateValueCount, 0L)
})

test_that("summary.PnuData reflects inserted rows", {
  pd <- createEmptyPnuData()
  on.exit(Andromeda::close(pd))

  # Insert 2 switchers and 3 comparators into cohorts
  Andromeda::appendToTable(pd$cohorts, dplyr::tibble(
    row_id = 1:5,
    person_seq_id = 1:5,
    person_id = as.character(1:5),
    cohort_start_date = rep(as.Date("2020-01-01"), 5),
    cohort_end_date   = rep(as.Date("2020-12-31"), 5),
    treatment         = c(1L, 1L, 0L, 0L, 0L),
    exposure_set_id   = c(1L, 1L, 1L, 1L, 1L)
  ))

  s <- summary(pd)
  expect_equal(s$switcherCount, 2L)
  expect_equal(s$comparatorCount, 3L)
})

test_that("show method prints without error", {
  pd <- createEmptyPnuData(metaData = list(
    databaseId = "testDb",
    targetCohortId = 1L,
    comparatorCohortId = 2L,
    outcomeCohortId = 3L
  ))
  on.exit(Andromeda::close(pd))
  expect_output(show(pd))
})

test_that("print.summary.PnuData prints without error", {
  pd <- createEmptyPnuData()
  on.exit(Andromeda::close(pd))
  expect_output(print(summary(pd)))
})
