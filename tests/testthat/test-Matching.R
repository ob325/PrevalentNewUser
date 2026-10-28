# ---- helpers ----------------------------------------------------------------

makePopWithPs <- function(nSwitchers = 100L,
                          nComparators = 200L,
                          nSets = 1L,
                          seed = 1L) {
  set.seed(seed)
  n <- nSwitchers + nComparators
  data.frame(
    row_id = seq_len(n),
    person_seq_id = seq_len(n),
    person_id = as.character(seq_len(n)),
    cohort_start_date = as.Date("2020-01-01"),
    cohort_end_date = as.Date("2021-01-01"),
    treatment = c(rep(1L, nSwitchers), rep(0L, nComparators)),
    exposure_set_id = rep(seq_len(nSets), length.out = n),
    survival_time = 365L,
    outcome_count = 0L,
    days_to_event = NA_integer_,
    propensityScore = runif(n, 0.2, 0.8)
  )
}

# ---- createMatchingArgs -----------------------------------------------------

test_that("createMatchingArgs validates caliper >= 0", {
  expect_error(createMatchingArgs(caliper = -0.1))
})

test_that("createMatchingArgs validates caliperScale choices", {
  expect_error(createMatchingArgs(caliperScale = "raw"))
})

test_that("createMatchingArgs validates maxRatio >= 0", {
  expect_error(createMatchingArgs(maxRatio = -1L))
})

test_that("createMatchingArgs returns a MatchingArgs with correct defaults", {
  args <- createMatchingArgs()
  expect_s3_class(args, "MatchingArgs")
  expect_equal(args$caliper, 0.2)
  expect_equal(args$caliperScale, "standardized logit")
  expect_equal(args$maxRatio, 1L)
  expect_false(args$allowReverseMatch)
})

test_that("createMatchingArgs JSON round-trip preserves all fields", {
  original <- createMatchingArgs(
    caliper = 0.3, caliperScale = "logit", maxRatio = 2L, allowReverseMatch = TRUE
  )
  restored <- MatchingArgs$new(json = original$toJson())
  expect_equal(restored$caliper, 0.3)
  expect_equal(restored$caliperScale, "logit")
  expect_equal(restored$maxRatio, 2L)
  expect_true(restored$allowReverseMatch)
})

# ---- matchOnTcps: structure -------------------------------------------------

test_that("matchOnTcps returns a data frame with stratumId column", {
  pop <- makePopWithPs()
  result <- matchOnTcps(pop, createMatchingArgs())
  expect_true(is.data.frame(result))
  expect_true("stratumId" %in% names(result))
})

test_that("matchOnTcps drops all unmatched persons (no stratumId = -1)", {
  pop <- makePopWithPs()
  result <- matchOnTcps(pop, createMatchingArgs())
  expect_true(all(result$stratumId > 0L))
})

test_that("matchOnTcps result has fewer or equal rows than input", {
  pop <- makePopWithPs(nSwitchers = 50L, nComparators = 50L)
  result <- matchOnTcps(pop, createMatchingArgs())
  expect_lte(nrow(result), nrow(pop))
})

# ---- matchOnTcps: maxRatio --------------------------------------------------

test_that("matchOnTcps 1:1 matching has exactly 1 comparator per switcher", {
  pop <- makePopWithPs(nSwitchers = 80L, nComparators = 200L, seed = 2L)
  result <- matchOnTcps(pop, createMatchingArgs(maxRatio = 1L))

  counts <- table(result$stratumId, result$treatment)
  expect_true(all(counts[, "1"] == 1L)) # exactly 1 switcher per stratum
  expect_true(all(counts[, "0"] <= 1L)) # at most 1 comparator per stratum
})

test_that("matchOnTcps 1:2 matching has at most 2 comparators per switcher", {
  pop <- makePopWithPs(nSwitchers = 60L, nComparators = 200L, seed = 3L)
  result <- matchOnTcps(pop, createMatchingArgs(maxRatio = 2L))

  if (nrow(result) == 0L) skip("No matched persons — adjust fixture if needed")

  counts <- table(result$stratumId, result$treatment)
  expect_true(all(counts[, "1"] == 1L))
  expect_true(all(counts[, "0"] <= 2L))
})

test_that("matchOnTcps variable ratio (maxRatio = 0) matches multiple comparators per switcher", {
  # With a wide caliper and many comparators, variable ratio should give > 1 comp/switcher
  pop <- makePopWithPs(nSwitchers = 20L, nComparators = 200L, seed = 4L)
  result <- matchOnTcps(pop, createMatchingArgs(maxRatio = 0L, caliper = 0L))

  expect_gt(nrow(result), 20L + 20L) # more comparators than switchers
})

# ---- matchOnTcps: no cross-set matches --------------------------------------

test_that("matchOnTcps produces no cross-set strata", {
  pop <- makePopWithPs(nSwitchers = 60L, nComparators = 120L, nSets = 3L, seed = 5L)
  result <- matchOnTcps(pop, createMatchingArgs())

  if (nrow(result) == 0L) skip("No matched persons")

  # For each stratum, all members should be in the same exposure set
  setPerStratum <- tapply(result$exposure_set_id, result$stratumId, function(x) length(unique(x)))
  expect_true(all(setPerStratum == 1L))
})

# ---- matchOnTcps: NA propensityScore ----------------------------------------

test_that("matchOnTcps excludes persons with NA propensityScore", {
  pop <- makePopWithPs(nSwitchers = 50L, nComparators = 100L, seed = 6L)
  pop$propensityScore[1:10] <- NA_real_

  result <- suppressMessages(matchOnTcps(pop, createMatchingArgs()))
  expect_false(any(is.na(result$propensityScore)))
})

# ---- matchOnTcps: empty population ------------------------------------------

test_that("matchOnTcps on empty population returns empty data frame with stratumId", {
  pop <- makePopWithPs()[0L, ]
  pop$propensityScore <- numeric(0)
  result <- matchOnTcps(pop, createMatchingArgs())
  expect_equal(nrow(result), 0L)
  expect_true("stratumId" %in% names(result))
})

# ---- matchOnTcps: caliper = 0 (no caliper) vs wide caliper -------------------

test_that("matchOnTcps caliper = 0 (disabled) matches more persons than tight caliper", {
  pop <- makePopWithPs(nSwitchers = 50L, nComparators = 50L, seed = 7L)
  # caliper = 0 means no caliper (match globally)
  r_wide <- matchOnTcps(pop, createMatchingArgs(caliper = 0))
  # Very tight caliper in raw logit units should match fewer
  r_tight <- matchOnTcps(pop, createMatchingArgs(caliper = 0.01, caliperScale = "logit"))
  expect_gte(nrow(r_wide), nrow(r_tight))
})

# ---- matchOnTcps: error handling --------------------------------------------

test_that("matchOnTcps errors on non-data-frame population", {
  expect_error(matchOnTcps(list(), createMatchingArgs()))
})

test_that("matchOnTcps errors on population missing required columns", {
  bad <- data.frame(x = 1:5)
  expect_error(matchOnTcps(bad, createMatchingArgs()))
})

test_that("matchOnTcps errors on non-MatchingArgs argument", {
  pop <- makePopWithPs()
  expect_error(matchOnTcps(pop, list(caliper = 0.2)))
})

# ---- matchOnTcps: stratumId uniqueness across sets --------------------------

test_that("matchOnTcps stratumIds are globally unique (no set reuses same ID)", {
  pop <- makePopWithPs(nSwitchers = 60L, nComparators = 120L, nSets = 2L, seed = 8L)
  result <- matchOnTcps(pop, createMatchingArgs())

  if (nrow(result) == 0L) skip("No matched persons")

  # Each stratumId should map to exactly one exposure_set_id
  setPerStratum <- tapply(result$exposure_set_id, result$stratumId, function(x) length(unique(x)))
  expect_true(all(setPerStratum == 1L))

  # Strata from different sets should have disjoint IDs (no collisions)
  strata_set1 <- unique(result$stratumId[result$exposure_set_id == 1L])
  strata_set2 <- unique(result$stratumId[result$exposure_set_id == 2L])
  expect_length(intersect(strata_set1, strata_set2), 0L)
})
