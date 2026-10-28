test_that("computeExposureSetsInR produces correct switcher rows for six-patient fixture", {
  f <- makeSixPatientFixture()

  result <- computeExposureSetsInR(
    treatmentA = f$treatmentA,
    treatmentB = f$treatmentB,
    observationPeriod = f$observationPeriod,
    exposureSetDefinition = "time"
  )

  switchers <- result[result$is_switcher, ]

  # Three switchers
  expect_equal(nrow(switchers), 3L)

  # Persons 1 & 2 in set 120
  sw12 <- switchers[switchers$person_id %in% c("1", "2"), ]
  expect_equal(nrow(sw12), 2L)
  expect_true(all(sw12$exposure_set == f$daysAt4m))
  expect_true(all(sw12$index_date == f$switch4m))

  # Person 3 in set 270
  sw3 <- switchers[switchers$person_id == "3", ]
  expect_equal(nrow(sw3), 1L)
  expect_equal(sw3$exposure_set, f$daysAt9m)
  expect_equal(sw3$index_date, f$switch9m)
})

test_that("computeExposureSetsInR produces correct comparator rows for six-patient fixture", {
  f <- makeSixPatientFixture()

  result <- computeExposureSetsInR(
    treatmentA = f$treatmentA,
    treatmentB = f$treatmentB,
    observationPeriod = f$observationPeriod,
    exposureSetDefinition = "time"
  )

  comparators <- result[!result$is_switcher, ]

  # Persons 4-6 each appear in both set 120 and set 270 = 6 rows
  expect_equal(nrow(comparators), 6L)
  expect_setequal(comparators$person_id, c("4", "5", "6"))

  # Each comparator appears twice (once per set)
  for (pid in c("4", "5", "6")) {
    rows <- comparators[comparators$person_id == pid, ]
    expect_equal(nrow(rows), 2L, info = paste("person", pid))
    expect_setequal(rows$exposure_set, c(f$daysAt4m, f$daysAt9m))
  }

  # Comparator index dates are determined by their own A history, not calendar time
  comp120 <- comparators[comparators$exposure_set == f$daysAt4m, ]
  expect_true(all(comp120$index_date == f$switch4m))

  comp270 <- comparators[comparators$exposure_set == f$daysAt9m, ]
  expect_true(all(comp270$index_date == f$switch9m))
})

test_that("computeExposureSetsInR: switcher with no prior A gets exposure_set = 0", {
  # Person 99 is in treatmentB only (never on A)
  treatmentA <- data.frame(
    cohort_definition_id = 1L,
    subject_id = 1L,
    cohort_start_date = as.Date("2020-01-01"),
    cohort_end_date = as.Date("2022-12-31"),
    stringsAsFactors = FALSE
  )
  treatmentB <- data.frame(
    cohort_definition_id = 2L,
    subject_id = 99L,
    cohort_start_date = as.Date("2020-06-01"),
    cohort_end_date = as.Date("2022-12-31"),
    stringsAsFactors = FALSE
  )
  observationPeriod <- data.frame(
    person_id = c(1L, 99L),
    observation_period_start_date = rep(as.Date("2019-01-01"), 2L),
    observation_period_end_date = rep(as.Date("2022-12-31"), 2L),
    stringsAsFactors = FALSE
  )

  result <- computeExposureSetsInR(treatmentA, treatmentB, observationPeriod)

  set0 <- result[result$person_id == "99", ]
  expect_equal(nrow(set0), 1L)
  expect_equal(set0$exposure_set, 0L)
  expect_equal(set0$is_switcher, TRUE)
  expect_equal(set0$index_date, as.Date("2020-06-01"))
})

test_that("computeExposureSetsInR: switcher partway through first era gets correct days count", {
  # Person 1 starts A on Jan 1, switches to B on day 50 (Feb 19, 2020)
  switchDate <- as.Date("2020-01-01") + 50L
  treatmentA <- data.frame(
    cohort_definition_id = 1L,
    subject_id = 1L,
    cohort_start_date = as.Date("2020-01-01"),
    cohort_end_date = switchDate - 1L,
    stringsAsFactors = FALSE
  )
  treatmentB <- data.frame(
    cohort_definition_id = 2L,
    subject_id = 1L,
    cohort_start_date = switchDate,
    cohort_end_date = as.Date("2022-12-31"),
    stringsAsFactors = FALSE
  )
  observationPeriod <- data.frame(
    person_id = 1L,
    observation_period_start_date = as.Date("2019-01-01"),
    observation_period_end_date = as.Date("2022-12-31"),
    stringsAsFactors = FALSE
  )

  result <- computeExposureSetsInR(treatmentA, treatmentB, observationPeriod)

  sw <- result[result$is_switcher, ]
  expect_equal(sw$exposure_set, 50L)
  expect_equal(sw$index_date, switchDate)
})

test_that("computeExposureSetsInR: comparator not on A at candidate index date is excluded", {
  # Switcher (person 1) has 30 days on A, switches on day 30.
  # Person 2 only has A era from day 0 to day 20 — too short.
  switchDate <- as.Date("2020-01-01") + 30L
  treatmentA <- data.frame(
    cohort_definition_id = 1L,
    subject_id = c(1L, 2L),
    cohort_start_date = c(as.Date("2020-01-01"), as.Date("2020-01-01")),
    cohort_end_date = c(switchDate - 1L, as.Date("2020-01-01") + 20L),
    stringsAsFactors = FALSE
  )
  treatmentB <- data.frame(
    cohort_definition_id = 2L,
    subject_id = 1L,
    cohort_start_date = switchDate,
    cohort_end_date = as.Date("2022-12-31"),
    stringsAsFactors = FALSE
  )
  observationPeriod <- data.frame(
    person_id = c(1L, 2L),
    observation_period_start_date = rep(as.Date("2019-01-01"), 2L),
    observation_period_end_date = rep(as.Date("2022-12-31"), 2L),
    stringsAsFactors = FALSE
  )

  result <- computeExposureSetsInR(treatmentA, treatmentB, observationPeriod)

  # Person 2's A era ends on day 20; they are NOT on A at day 30 → not a comparator
  expect_equal(nrow(result), 1L)
  expect_equal(result$person_id, "1")
  expect_true(result$is_switcher)
})

test_that("computeExposureSetsInR handles fills definition", {
  # Person 1: 2 fills of A, switches to B at start of 3rd fill
  # Person 2: only 1 fill → eligible comparator for fills set 1, not 2
  # Person 3: 3 fills → eligible for both sets 1 and 2
  fill1Start <- as.Date("2020-01-01")
  fill2Start <- as.Date("2020-04-01")
  fill3Start <- as.Date("2020-07-01")
  switchDate <- fill3Start  # switches exactly when 3rd fill starts

  treatmentA <- data.frame(
    cohort_definition_id = 1L,
    subject_id = c(1L, 1L, 2L, 3L, 3L, 3L),
    cohort_start_date = c(fill1Start, fill2Start, fill1Start, fill1Start, fill2Start, fill3Start),
    cohort_end_date = c(
      fill2Start - 1L, switchDate - 1L,  # person 1 eras
      as.Date("2022-12-31"),             # person 2 (one long era)
      fill2Start - 1L, fill3Start - 1L, as.Date("2022-12-31")  # person 3 eras
    ),
    stringsAsFactors = FALSE
  )
  treatmentB <- data.frame(
    cohort_definition_id = 2L,
    subject_id = 1L,
    cohort_start_date = switchDate,
    cohort_end_date = as.Date("2022-12-31"),
    stringsAsFactors = FALSE
  )
  observationPeriod <- data.frame(
    person_id = c(1L, 2L, 3L),
    observation_period_start_date = rep(as.Date("2019-01-01"), 3L),
    observation_period_end_date = rep(as.Date("2022-12-31"), 3L),
    stringsAsFactors = FALSE
  )

  result <- computeExposureSetsInR(
    treatmentA, treatmentB, observationPeriod,
    exposureSetDefinition = "fills"
  )

  # Switcher: person 1 started 2 fills before switching → set 2
  sw <- result[result$is_switcher, ]
  expect_equal(sw$exposure_set, 2L)

  comparators <- result[!result$is_switcher, ]
  # Person 2 has 1 fill (long era, but only 1 era) → eligible for set 1, not set 2
  comp2 <- comparators[comparators$person_id == "2", ]
  expect_equal(nrow(comp2), 0L)  # only set 2 exists (from switcher), person 2 has only 1 fill

  # Person 3 has 3 fills → fill 2 starts fill2Start
  comp3 <- comparators[comparators$person_id == "3", ]
  expect_equal(nrow(comp3), 1L)
  expect_equal(comp3$exposure_set, 2L)
  expect_equal(comp3$index_date, fill2Start)
})

test_that("computeExposureSetsInR returns empty data frame when no switchers", {
  f <- makeSixPatientFixture()
  result <- computeExposureSetsInR(
    treatmentA = f$treatmentA,
    treatmentB = f$treatmentB[integer(0), ],
    observationPeriod = f$observationPeriod
  )
  expect_equal(nrow(result), 0L)
  expect_named(result, c("person_id", "exposure_set", "index_date", "is_switcher"))
})

test_that("computeExposureSetsInR errors on wrong exposureSetDefinition", {
  f <- makeSixPatientFixture()
  expect_error(
    computeExposureSetsInR(f$treatmentA, f$treatmentB, f$observationPeriod,
      exposureSetDefinition = "bad"
    )
  )
})

# ---- Set-0 equivalence: all switchers have no prior A ----------------------
#
# When every B-starter has zero prior A their exposure_set is 0, and
# computeExposureSetsInR() returns ONLY switcher rows (set-0 comparators
# require calendar-date matching deferred to createStudyPopulation()).
# This means the returned person_id + is_switcher column exactly reproduces
# the ACNU "target" set — the same persons CohortMethod would label as targets.

test_that("set-0: all switchers labelled is_switcher=TRUE with exposure_set=0", {
  b_starts <- as.Date(c("2020-03-01", "2020-07-01", "2020-11-01"))

  # Persons 1-3 start B with zero prior A (pure new users of B).
  treatmentA <- data.frame(
    cohort_definition_id = 1L,
    subject_id           = c(4L, 5L),
    cohort_start_date    = as.Date(c("2020-01-01", "2020-01-01")),
    cohort_end_date      = as.Date(c("2022-12-31", "2022-12-31")),
    stringsAsFactors     = FALSE
  )
  treatmentB <- data.frame(
    cohort_definition_id = 2L,
    subject_id           = c(1L, 2L, 3L),
    cohort_start_date    = b_starts,
    cohort_end_date      = rep(as.Date("2022-12-31"), 3L),
    stringsAsFactors     = FALSE
  )
  observationPeriod <- data.frame(
    person_id                     = c(1L, 2L, 3L, 4L, 5L),
    observation_period_start_date = rep(as.Date("2019-01-01"), 5L),
    observation_period_end_date   = rep(as.Date("2022-12-31"), 5L),
    stringsAsFactors              = FALSE
  )

  result <- computeExposureSetsInR(treatmentA, treatmentB, observationPeriod)

  # Exactly the three B-starters, all in set 0, all marked as switchers.
  # This is the ACNU target set.
  expect_equal(nrow(result), 3L)
  expect_setequal(result$person_id, c("1", "2", "3"))
  expect_true(all(result$exposure_set == 0L))
  expect_true(all(result$is_switcher))

  # Index dates are the B start dates (same as ACNU index dates)
  result_sorted <- result[order(result$person_id), ]
  expect_equal(result_sorted$index_date, sort(b_starts))

  # A-only persons 4 and 5 do not appear (set-0 comparators are deferred)
  expect_false(any(result$person_id %in% c("4", "5")))
})

test_that("set-0: fills definition also assigns exposure_set=0 for no-prior-A switchers", {
  treatmentB <- data.frame(
    cohort_definition_id = 2L,
    subject_id           = 1L,
    cohort_start_date    = as.Date("2020-06-01"),
    cohort_end_date      = as.Date("2022-12-31"),
    stringsAsFactors     = FALSE
  )
  observationPeriod <- data.frame(
    person_id                     = 1L,
    observation_period_start_date = as.Date("2019-01-01"),
    observation_period_end_date   = as.Date("2022-12-31"),
    stringsAsFactors              = FALSE
  )

  result <- computeExposureSetsInR(
    treatmentA        = data.frame(
      cohort_definition_id = integer(0), subject_id = integer(0),
      cohort_start_date    = as.Date(character(0)),
      cohort_end_date      = as.Date(character(0))
    ),
    treatmentB        = treatmentB,
    observationPeriod = observationPeriod,
    exposureSetDefinition = "fills"
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$exposure_set, 0L)
  expect_true(result$is_switcher)
})

# ---- SQL translation tests (no database required) ------------------------

test_that("GetExposureSets.sql translates without error for all target dialects", {
  sqlFile <- system.file("sql", "sql_server", "GetExposureSets.sql",
    package = "PrevalentNewUser"
  )
  sql <- SqlRender::readSql(sqlFile)
  rendered <- SqlRender::render(sql,
    cohort_database_schema = "scratch",
    cohort_table = "cohort",
    target_cohort_id = 1L,
    comparator_cohort_id = 2L,
    exposure_set_definition = "time"
  )
  dialects <- c(
    "sql server", "postgresql", "redshift",
    "oracle", "snowflake", "spark", "bigquery", "sqlite"
  )
  for (d in dialects) {
    out <- try(SqlRender::translate(rendered, targetDialect = d), silent = TRUE)
    expect_false(inherits(out, "try-error"), label = paste("dialect:", d))
  }
})

test_that("DropExposureSets.sql translates without error for all target dialects", {
  sqlFile <- system.file("sql", "sql_server", "DropExposureSets.sql",
    package = "PrevalentNewUser"
  )
  sql <- SqlRender::readSql(sqlFile)
  rendered <- SqlRender::render(sql)
  for (d in c("sql server", "postgresql", "redshift",
               "oracle", "snowflake", "spark", "bigquery", "sqlite")) {
    out <- try(SqlRender::translate(rendered, targetDialect = d), silent = TRUE)
    expect_false(inherits(out, "try-error"), label = paste("dialect:", d))
  }
})

test_that("GetExposureSets.sql renders with fills definition without error", {
  sqlFile <- system.file("sql", "sql_server", "GetExposureSets.sql",
    package = "PrevalentNewUser"
  )
  rendered <- SqlRender::render(
    SqlRender::readSql(sqlFile),
    cohort_database_schema = "scratch",
    cohort_table = "cohort",
    target_cohort_id = 1L,
    comparator_cohort_id = 2L,
    exposure_set_definition = "fills"
  )
  expect_no_error(SqlRender::translate(rendered, targetDialect = "postgresql"))
})

# ---- Eunomia comparison test (skipped if Eunomia not available) ----------

test_that("getDbExposureSets matches computeExposureSetsInR on six-patient fixture", {
  skip_if(!eunomiaAvailable(), "Eunomia not installed")

  f <- makeSixPatientFixture()

  # Set up a clean in-memory Eunomia database
  connectionDetails <- Eunomia::getEunomiaConnectionDetails()
  conn <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  # Insert the six-patient fixture into a cohort table
  cohortData <- rbind(f$treatmentA, f$treatmentB)
  DatabaseConnector::insertTable(
    connection = conn,
    tableName = "main.cohort",
    data = cohortData,
    createTable = TRUE,
    dropTableIfExists = TRUE
  )

  # Insert observation period
  DatabaseConnector::insertTable(
    connection = conn,
    tableName = "main.observation_period",
    data = f$observationPeriod[, c(
      "person_id",
      "observation_period_start_date",
      "observation_period_end_date"
    )],
    createTable = FALSE,
    dropTableIfExists = FALSE
  )

  # SQL result
  sqlResult <- getDbExposureSets(
    connection = conn,
    cohortDatabaseSchema = "main",
    cohortTable = "cohort",
    targetCohortId = 1L,
    comparatorCohortId = 2L,
    exposureSetDefinition = "time"
  )

  # R reference result
  rResult <- computeExposureSetsInR(
    treatmentA = f$treatmentA,
    treatmentB = f$treatmentB,
    observationPeriod = f$observationPeriod,
    exposureSetDefinition = "time"
  )

  # Normalise both to the same sort order for comparison
  normSort <- function(df) {
    df[order(df$person_id, df$exposure_set), ]
  }
  sqlNorm <- normSort(as.data.frame(sqlResult))
  rNorm <- normSort(rResult)

  expect_equal(nrow(sqlNorm), nrow(rNorm))
  expect_equal(sqlNorm$person_id, rNorm$person_id)
  expect_equal(sqlNorm$exposure_set, rNorm$exposure_set)
  expect_equal(sqlNorm$index_date, rNorm$index_date)
  expect_equal(sqlNorm$is_switcher, rNorm$is_switcher)
})
