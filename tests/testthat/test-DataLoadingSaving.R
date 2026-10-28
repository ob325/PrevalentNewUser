# ---- SQL translation tests (no database required) ---------------------------

test_that("GetCohorts.sql translates without error for all dialects", {
  sqlFile <- system.file("sql", "sql_server", "GetCohorts.sql",
    package = "PrevalentNewUser"
  )
  rendered <- SqlRender::render(
    SqlRender::readSql(sqlFile),
    cohort_database_schema = "scratch",
    cohort_table           = "cohort",
    target_cohort_id       = 1L,
    comparator_cohort_id   = 2L
  )
  dialects <- c(
    "sql server", "postgresql", "redshift",
    "oracle", "snowflake", "spark", "bigquery", "sqlite"
  )
  for (d in dialects) {
    out <- try(SqlRender::translate(rendered, targetDialect = d), silent = TRUE)
    expect_false(inherits(out, "try-error"), label = paste("GetCohorts dialect:", d))
  }
})

test_that("DropCohorts.sql translates without error for all dialects", {
  sqlFile <- system.file("sql", "sql_server", "DropCohorts.sql",
    package = "PrevalentNewUser"
  )
  rendered <- SqlRender::render(SqlRender::readSql(sqlFile))
  for (d in c(
    "sql server", "postgresql", "redshift",
    "oracle", "snowflake", "spark", "bigquery", "sqlite"
  )) {
    out <- try(SqlRender::translate(rendered, targetDialect = d), silent = TRUE)
    expect_false(inherits(out, "try-error"), label = paste("DropCohorts dialect:", d))
  }
})

# ---- save / load (no database required) -------------------------------------

test_that("savePnuData / loadPnuData round-trip preserves tables and metaData", {
  pnuData <- createEmptyPnuData(metaData = list(targetCohortId = 1L, tag = "test"))

  # Write a row to each table
  pnuData$cohorts <- dplyr::tibble(
    row_id = 1L, person_seq_id = 1L, person_id = "42",
    cohort_start_date = as.Date("2020-01-01"),
    cohort_end_date   = as.Date("2021-01-01"),
    treatment = 1L, exposure_set_id = 120L
  )
  pnuData$outcomes <- dplyr::tibble(
    person_seq_id = 1L, outcome_id = 3L,
    outcome_date = as.Date("2020-06-01")
  )
  pnuData$exposureSets <- dplyr::tibble(
    person_seq_id = 1L, exposure_set_id = 120L, days_on_a = 120L
  )

  zipFile <- tempfile(fileext = ".zip")
  on.exit(unlink(zipFile))

  savePnuData(pnuData, zipFile)
  Andromeda::close(pnuData)

  loaded <- loadPnuData(zipFile)
  on.exit(Andromeda::close(loaded), add = TRUE)

  expect_true(isPnuData(loaded))
  expect_equal(attr(loaded, "metaData")$targetCohortId, 1L)
  expect_equal(attr(loaded, "metaData")$tag, "test")

  cohortLoaded <- dplyr::collect(loaded$cohorts)
  expect_equal(nrow(cohortLoaded), 1L)
  expect_equal(cohortLoaded$person_id, "42")
  expect_equal(cohortLoaded$exposure_set_id, 120L)

  outLoaded <- dplyr::collect(loaded$outcomes)
  expect_equal(nrow(outLoaded), 1L)
  expect_equal(outLoaded$outcome_date, as.Date("2020-06-01"))

  esLoaded <- dplyr::collect(loaded$exposureSets)
  expect_equal(nrow(esLoaded), 1L)
  expect_equal(esLoaded$days_on_a, 120L)
})

test_that("savePnuData errors on non-PnuData input", {
  expect_error(savePnuData(list(), tempfile()))
})

test_that("loadPnuData errors on missing file", {
  expect_error(loadPnuData("/no/such/file.zip"))
})

# ---- Eunomia integration test -----------------------------------------------

test_that("getDbPnuData returns valid PnuData on six-patient fixture", {
  skip_if(!eunomiaAvailable(), "Eunomia not installed")

  f <- makeSixPatientFixture()

  connectionDetails <- Eunomia::getEunomiaConnectionDetails()
  conn <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  # Load fixture into the cohort table (also adds outcome rows for person 1-3)
  cohortData <- rbind(f$treatmentA, f$treatmentB)
  DatabaseConnector::insertTable(
    connection       = conn,
    tableName        = "main.cohort",
    data             = cohortData,
    createTable      = TRUE,
    dropTableIfExists = TRUE
  )

  cohortArgs <- createPnuCohortArgs(
    targetCohortId     = 1L,
    comparatorCohortId = 2L,
    outcomeCohortId    = 3L
  )
  covSettings <- FeatureExtraction::createCovariateSettings(
    useDemographicsGender = TRUE,
    useDemographicsAge    = TRUE
  )

  pnuData <- getDbPnuData(
    connection           = conn,
    cdmDatabaseSchema    = "main",
    cohortDatabaseSchema = "main",
    cohortTable          = "cohort",
    pnuCohortArgs        = cohortArgs,
    covariateSettings    = covSettings
  )
  on.exit(Andromeda::close(pnuData), add = TRUE)

  expect_true(isPnuData(pnuData))

  cohorts <- dplyr::collect(pnuData$cohorts)
  # 3 switchers + 6 comparator rows (persons 4-6 in both sets)
  expect_equal(sum(cohorts$treatment == 1L), 3L)
  expect_equal(sum(cohorts$treatment == 0L), 6L)

  # Two exposure sets (one per switcher group)
  esets <- dplyr::collect(pnuData$exposureSets)
  expect_equal(dplyr::n_distinct(esets$exposure_set_id), 2L)

  # metaData populated
  md <- attr(pnuData, "metaData")
  expect_equal(md$targetCohortId,     1L)
  expect_equal(md$comparatorCohortId, 2L)
  expect_equal(md$outcomeCohortId,    3L)
})

test_that("getDbPnuData / savePnuData / loadPnuData round-trip on Eunomia", {
  skip_if(!eunomiaAvailable(), "Eunomia not installed")

  f <- makeSixPatientFixture()

  connectionDetails <- Eunomia::getEunomiaConnectionDetails()
  conn <- DatabaseConnector::connect(connectionDetails)
  on.exit(DatabaseConnector::disconnect(conn), add = TRUE)

  cohortData <- rbind(f$treatmentA, f$treatmentB)
  DatabaseConnector::insertTable(
    connection       = conn,
    tableName        = "main.cohort",
    data             = cohortData,
    createTable      = TRUE,
    dropTableIfExists = TRUE
  )

  cohortArgs  <- createPnuCohortArgs(
    targetCohortId = 1L, comparatorCohortId = 2L, outcomeCohortId = 3L
  )
  covSettings <- FeatureExtraction::createCovariateSettings(
    useDemographicsGender = TRUE
  )

  pnuData <- getDbPnuData(
    connection           = conn,
    cdmDatabaseSchema    = "main",
    cohortDatabaseSchema = "main",
    cohortTable          = "cohort",
    pnuCohortArgs        = cohortArgs,
    covariateSettings    = covSettings
  )

  zipFile <- tempfile(fileext = ".zip")
  on.exit({
    unlink(zipFile)
    try(Andromeda::close(pnuData), silent = TRUE)
  }, add = TRUE)

  savePnuData(pnuData, zipFile)
  Andromeda::close(pnuData)

  loaded <- loadPnuData(zipFile)
  on.exit(Andromeda::close(loaded), add = TRUE)

  expect_true(isPnuData(loaded))

  # Same cohort counts after round-trip
  cohortsOrig   <- dplyr::collect(pnuData$cohorts)
  cohortsLoaded <- dplyr::collect(loaded$cohorts)

  # pnuData was closed, access loaded instead
  cohortsLoaded <- dplyr::collect(loaded$cohorts)
  expect_equal(nrow(cohortsLoaded), 9L)  # 3 switchers + 6 comparator rows
  expect_equal(attr(loaded, "metaData")$targetCohortId, 1L)
})
