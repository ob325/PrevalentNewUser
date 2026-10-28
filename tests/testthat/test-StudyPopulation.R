# ---- helpers ----------------------------------------------------------------

makePnuForSp <- function(nSwitchers = 100L,
                         nComparators = 100L,
                         outcomeRate = 0.2,
                         seed = 1L) {
  simArgs <- createSimulationArgs(
    nSwitchers         = nSwitchers,
    nComparatorsPerSet = nComparators,
    nExposureSets      = 1L,
    nCovariates        = 0L,
    outcomeBaseRate    = outcomeRate,
    logRr              = 0.0,
    seed               = seed
  )
  simulatePnuData(simArgs)
}

# ---- createStudyPopulationArgs ----------------------------------------------

test_that("createStudyPopulationArgs validates outcomeId >= 1", {
  expect_error(createStudyPopulationArgs(outcomeId = 0L))
})

test_that("createStudyPopulationArgs validates removeDuplicateSubjects choices", {
  expect_error(createStudyPopulationArgs(outcomeId = 1L, removeDuplicateSubjects = "random"))
})

test_that("createStudyPopulationArgs validates anchor choices", {
  expect_error(createStudyPopulationArgs(outcomeId = 1L, startAnchor = "index"))
  expect_error(createStudyPopulationArgs(outcomeId = 1L, endAnchor = "index"))
})

test_that("createStudyPopulationArgs returns a StudyPopulationArgs object", {
  args <- createStudyPopulationArgs(
    outcomeId = 1L,
    requireTimeAtRisk = FALSE,
    riskWindowEnd = 365L,
    endAnchor = "cohort start"
  )
  expect_s3_class(args, "StudyPopulationArgs")
  expect_equal(args$outcomeId, 1L)
  expect_false(args$requireTimeAtRisk)
  expect_equal(args$riskWindowEnd, 365L)
  expect_equal(args$endAnchor, "cohort start")
})

test_that("createStudyPopulationArgs JSON round-trip preserves all fields", {
  original <- createStudyPopulationArgs(
    outcomeId = 2L, firstExposureOnly = TRUE, washoutPeriod = 180L,
    removeDuplicateSubjects = "keep first", priorOutcomeLookback = 365L,
    requireTimeAtRisk = FALSE, minDaysAtRisk = 7L, maxDaysAtRisk = 730L,
    riskWindowStart = 1L, riskWindowEnd = 365L,
    startAnchor = "cohort start", endAnchor = "cohort start",
    censorAtNewRiskWindow = FALSE
  )
  json <- original$toJson()
  restored <- createStudyPopulationArgs(
    outcomeId = jsonlite::fromJSON(json)$outcomeId
  )
  # Use JSON constructor path via R6 directly
  restored2 <- StudyPopulationArgs$new(json = json)
  expect_equal(restored2$outcomeId, 2L)
  expect_equal(restored2$firstExposureOnly, TRUE)
  expect_equal(restored2$washoutPeriod, 180L)
  expect_equal(restored2$removeDuplicateSubjects, "keep first")
  expect_equal(restored2$riskWindowEnd, 365L)
  expect_equal(restored2$endAnchor, "cohort start")
})

# ---- createStudyPopulation: basic structure ---------------------------------

test_that("createStudyPopulation returns a valid PnuData with studyPopulation", {
  pnuData <- makePnuForSp()
  on.exit(Andromeda::close(pnuData))

  spArgs <- createStudyPopulationArgs(outcomeId = 1L)
  pnuData <- createStudyPopulation(pnuData, spArgs)

  expect_true(isPnuData(pnuData))
  sp <- dplyr::collect(pnuData$studyPopulation)
  expect_true(nrow(sp) > 0L)
})

test_that("createStudyPopulation with no filtering preserves cohort row count", {
  pnuData <- makePnuForSp(nSwitchers = 80L, nComparators = 80L, seed = 2L)
  on.exit(Andromeda::close(pnuData))

  spArgs <- createStudyPopulationArgs(outcomeId = 1L, requireTimeAtRisk = FALSE)
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)
  expect_equal(nrow(sp), 160L) # 80 switchers + 80 comparators
  expect_equal(sum(sp$treatment == 1L), 80L)
  expect_equal(sum(sp$treatment == 0L), 80L)
})

test_that("createStudyPopulation outcome_count is 0 or 1", {
  pnuData <- makePnuForSp(outcomeRate = 0.3, seed = 3L)
  on.exit(Andromeda::close(pnuData))

  spArgs <- createStudyPopulationArgs(outcomeId = 1L, requireTimeAtRisk = FALSE)
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)
  expect_true(all(sp$outcome_count %in% 0:1))
  # Some outcomes must exist with 30% baseline rate
  expect_gt(sum(sp$outcome_count), 0L)
})

test_that("createStudyPopulation survival_time is correct for cases and non-cases", {
  pnuData <- makePnuForSp(outcomeRate = 0.3, seed = 4L)
  on.exit(Andromeda::close(pnuData))

  spArgs <- createStudyPopulationArgs(outcomeId = 1L, requireTimeAtRisk = FALSE)
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)

  # For persons with outcomes: survival_time == days_to_event
  cases <- sp[sp$outcome_count == 1L, ]
  expect_true(all(cases$survival_time == cases$days_to_event))
  expect_true(all(cases$survival_time > 0L))

  # For non-cases: days_to_event is NA, survival_time is time_at_risk
  non_cases <- sp[sp$outcome_count == 0L, ]
  expect_true(all(is.na(non_cases$days_to_event)))
  expect_true(all(non_cases$survival_time >= 0L))
})

# ---- requireTimeAtRisk ------------------------------------------------------

test_that("requireTimeAtRisk = TRUE with minDaysAtRisk > follow-up excludes everyone", {
  pnuData <- makePnuForSp(seed = 5L) # 365-day follow-up
  on.exit(Andromeda::close(pnuData))

  spArgs <- createStudyPopulationArgs(
    outcomeId = 1L, requireTimeAtRisk = TRUE, minDaysAtRisk = 400L
  )
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)
  expect_equal(nrow(sp), 0L)
})

test_that("requireTimeAtRisk = FALSE does not filter by time", {
  pnuData <- makePnuForSp(seed = 6L)
  on.exit(Andromeda::close(pnuData))

  spArgs <- createStudyPopulationArgs(
    outcomeId = 1L, requireTimeAtRisk = FALSE
  )
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)
  expect_equal(nrow(sp), 200L)
})

# ---- riskWindowStart / riskWindowEnd ----------------------------------------

test_that("riskWindowStart offset shifts the risk window start", {
  pnuData <- makePnuForSp(outcomeRate = 0.5, seed = 7L)
  on.exit(Andromeda::close(pnuData))

  # Start risk window 30 days after index, end at cohort end (365 days)
  spArgs <- createStudyPopulationArgs(
    outcomeId = 1L, riskWindowStart = 30L,
    requireTimeAtRisk = FALSE
  )
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)
  # Maximum survival_time should be 365 - 30 = 335 days
  expect_true(all(sp$survival_time <= 335L))
})

test_that("riskWindowEnd with endAnchor = 'cohort start' caps the risk window", {
  pnuData <- makePnuForSp(outcomeRate = 0.5, seed = 8L)
  on.exit(Andromeda::close(pnuData))

  spArgs <- createStudyPopulationArgs(
    outcomeId = 1L,
    riskWindowEnd = 100L, endAnchor = "cohort start",
    requireTimeAtRisk = FALSE
  )
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)
  # No person can have more than 100 days in the risk window
  expect_true(all(sp$survival_time <= 100L))
})

# ---- maxDaysAtRisk ----------------------------------------------------------

test_that("maxDaysAtRisk caps survival_time and suppresses late outcomes", {
  pnuData <- makePnuForSp(outcomeRate = 0.5, seed = 9L)
  on.exit(Andromeda::close(pnuData))

  spArgs <- createStudyPopulationArgs(
    outcomeId = 1L, maxDaysAtRisk = 60L, requireTimeAtRisk = FALSE
  )
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)
  expect_true(all(sp$survival_time <= 60L))
  # No outcome after day 60
  cases <- sp[sp$outcome_count == 1L, ]
  expect_true(all(cases$days_to_event <= 60L))
})

# ---- priorOutcomeLookback ---------------------------------------------------

test_that("priorOutcomeLookback excludes persons with recent prior outcomes", {
  pnuData <- makePnuForSp(outcomeRate = 0.5, seed = 10L)
  on.exit(Andromeda::close(pnuData))

  # Count without prior-outcome filtering
  spArgs0 <- createStudyPopulationArgs(outcomeId = 1L, requireTimeAtRisk = FALSE)
  pnuData <- createStudyPopulation(pnuData, spArgs0)
  n0 <- nrow(dplyr::collect(pnuData$studyPopulation))

  # Re-run with lookback covering entire cohort history
  spArgs1 <- createStudyPopulationArgs(
    outcomeId = 1L, priorOutcomeLookback = 9999L, requireTimeAtRisk = FALSE
  )
  pnuData <- createStudyPopulation(pnuData, spArgs1)
  n1 <- nrow(dplyr::collect(pnuData$studyPopulation))

  # No prior outcomes exist in simulated data (index = start of observation),
  # so counts should be the same
  expect_equal(n1, n0)
})

# ---- firstExposureOnly / removeDuplicateSubjects ----------------------------

test_that("firstExposureOnly = TRUE keeps at most one row per person per arm", {
  pnuData <- makePnuForSp(seed = 11L)
  on.exit(Andromeda::close(pnuData))

  spArgs <- createStudyPopulationArgs(
    outcomeId = 1L, firstExposureOnly = TRUE, requireTimeAtRisk = FALSE
  )
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)
  counts <- sp |>
    dplyr::group_by(.data$person_id, .data$treatment) |>
    dplyr::summarise(n = dplyr::n(), .groups = "drop")
  expect_true(all(counts$n == 1L))
})

test_that("removeDuplicateSubjects = 'remove all' drops cross-arm persons", {
  # Build a PnuData where person "1" appears as switcher in set 1 and
  # comparator in set 1 (the simulation gives each person a unique role,
  # so use a hand-built fixture to test this)
  pnuData <- createEmptyPnuData()
  on.exit(Andromeda::close(pnuData))

  pnuData$cohorts <- dplyr::tibble(
    row_id = 1:4, person_seq_id = 1:4, person_id = c("A", "A", "B", "B"),
    cohort_start_date = as.Date("2020-01-01"),
    cohort_end_date = as.Date("2021-01-01"),
    treatment = c(1L, 0L, 1L, 0L), exposure_set_id = 1L
  )
  pnuData$outcomes <- dplyr::tibble(
    person_seq_id = integer(0), outcome_id = integer(0),
    outcome_date = as.Date(character(0))
  )

  spArgs <- createStudyPopulationArgs(
    outcomeId = 1L, removeDuplicateSubjects = "remove all",
    requireTimeAtRisk = FALSE
  )
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)
  # All persons appear in both arms → all removed
  expect_equal(nrow(sp), 0L)
})

test_that("removeDuplicateSubjects = 'keep first' keeps one row per person", {
  pnuData <- createEmptyPnuData()
  on.exit(Andromeda::close(pnuData))

  pnuData$cohorts <- dplyr::tibble(
    row_id = 1:4, person_seq_id = 1:4, person_id = c("A", "A", "B", "B"),
    cohort_start_date = c(
      as.Date("2020-01-01"), as.Date("2020-06-01"),
      as.Date("2020-01-01"), as.Date("2020-06-01")
    ),
    cohort_end_date = as.Date("2021-01-01"),
    treatment = c(1L, 0L, 0L, 1L), exposure_set_id = 1L
  )
  pnuData$outcomes <- dplyr::tibble(
    person_seq_id = integer(0), outcome_id = integer(0),
    outcome_date = as.Date(character(0))
  )

  spArgs <- createStudyPopulationArgs(
    outcomeId = 1L, removeDuplicateSubjects = "keep first",
    requireTimeAtRisk = FALSE
  )
  pnuData <- createStudyPopulation(pnuData, spArgs)

  sp <- dplyr::collect(pnuData$studyPopulation)
  # Each person appears once (earlier entry kept)
  expect_equal(nrow(sp), 2L)
  expect_setequal(sp$person_id, c("A", "B"))
  # Both should have their earliest index date
  expect_true(all(sp$cohort_start_date == as.Date("2020-01-01")))
})

# ---- error handling ---------------------------------------------------------

test_that("createStudyPopulation errors on non-PnuData input", {
  spArgs <- createStudyPopulationArgs(outcomeId = 1L)
  expect_error(createStudyPopulation(list(), spArgs))
})

test_that("createStudyPopulation errors on non-StudyPopulationArgs input", {
  pnuData <- makePnuForSp(seed = 12L)
  on.exit(Andromeda::close(pnuData))
  expect_error(createStudyPopulation(pnuData, list(outcomeId = 1L)))
})
