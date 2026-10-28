/*
 * Copyright 2026 Observational Health Data Sciences and Informatics
 *
 * This file is part of PrevalentNewUser
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* Default parameter values */
{DEFAULT @cohort_database_schema = 'main'}
{DEFAULT @cohort_table = 'cohort'}
{DEFAULT @target_cohort_id = 1}
{DEFAULT @comparator_cohort_id = 2}
{DEFAULT @exposure_set_definition = 'time'}

/*****************************************************************************
 * Step 1 — Switcher rows
 *
 * For each person in the comparator cohort (treatment B), compute their
 * exposure to treatment A before the B start date.
 *   "time"  → total days on A before B start
 *   "fills" → number of A eras (fills) started before B start
 *****************************************************************************/
DROP TABLE IF EXISTS #switcher_sets;

SELECT
  CAST(b.subject_id AS VARCHAR(30)) AS person_id,
  b.cohort_start_date                AS index_date,
  {@exposure_set_definition == 'time'} ? {
    COALESCE(SUM(
      DATEDIFF(
        DAY,
        a.cohort_start_date,
        CASE
          WHEN a.cohort_end_date < b.cohort_start_date
            THEN a.cohort_end_date
          ELSE DATEADD(DAY, -1, b.cohort_start_date)
        END
      ) + 1
    ), 0)
  } : {
    COALESCE(COUNT(a.cohort_start_date), 0)
  } AS exposure_set,
  CAST(1 AS INT) AS is_switcher
INTO #switcher_sets
FROM @cohort_database_schema.@cohort_table b
LEFT JOIN @cohort_database_schema.@cohort_table a
  ON  a.subject_id            = b.subject_id
  AND a.cohort_definition_id  = @target_cohort_id
  AND a.cohort_start_date     < b.cohort_start_date
WHERE b.cohort_definition_id = @comparator_cohort_id
GROUP BY
  b.subject_id,
  b.cohort_start_date;

/*****************************************************************************
 * Step 2 — Treatment-A eras for non-switchers, with running exposure totals
 *
 * For each comparator candidate (in target cohort, not in comparator cohort),
 * compute the cumulative A-exposure at the start of each era so that a later
 * join can identify which era contains a given exposure-set value.
 *
 *   "time"  → cum_exposure_before = total days on A before this era begins
 *             era_length          = days in this era
 *   "fills" → cum_exposure_before = number of A eras started before this era
 *             era_length          = 1  (each era = one fill)
 *****************************************************************************/
DROP TABLE IF EXISTS #a_era_cumsum;

SELECT
  CAST(a.subject_id AS VARCHAR(30)) AS person_id,
  a.cohort_start_date                AS era_start,
  a.cohort_end_date                  AS era_end,
  {@exposure_set_definition == 'time'} ? {
    DATEDIFF(DAY, a.cohort_start_date, a.cohort_end_date) + 1 AS era_length,
    COALESCE(
      SUM(DATEDIFF(DAY, a.cohort_start_date, a.cohort_end_date) + 1)
        OVER (
          PARTITION BY a.subject_id
          ORDER BY a.cohort_start_date
          ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ),
      0
    ) AS cum_exposure_before
  } : {
    1 AS era_length,
    ROW_NUMBER()
      OVER (PARTITION BY a.subject_id ORDER BY a.cohort_start_date) - 1
      AS cum_exposure_before
  }
INTO #a_era_cumsum
FROM @cohort_database_schema.@cohort_table a
WHERE a.cohort_definition_id = @target_cohort_id
  AND a.subject_id NOT IN (
    SELECT DISTINCT b2.subject_id
    FROM @cohort_database_schema.@cohort_table b2
    WHERE b2.cohort_definition_id = @comparator_cohort_id
  );

/*****************************************************************************
 * Step 3 — Comparator index dates
 *
 * For each unique exposure set E > 0 (from switchers), find every non-switcher
 * whose cumulative A-exposure reaches E inside one of their A eras.
 * The index date is the day within that era when E is first reached.
 *
 * Join condition: cum_exposure_before < E <= cum_exposure_before + era_length
 *   → the E-th day of A exposure falls within this era
 *
 * Index date:
 *   "time"  → era_start + (E − cum_exposure_before) days
 *   "fills" → era_start  (the start of the E-th fill)
 *****************************************************************************/
DROP TABLE IF EXISTS #comparator_sets;

SELECT
  aec.person_id,
  us.exposure_set,
  {@exposure_set_definition == 'time'} ? {
    DATEADD(DAY, us.exposure_set - aec.cum_exposure_before, aec.era_start)
  } : {
    aec.era_start
  } AS index_date,
  CAST(0 AS INT) AS is_switcher
INTO #comparator_sets
FROM #a_era_cumsum aec
INNER JOIN (
  SELECT DISTINCT exposure_set
  FROM #switcher_sets
  WHERE exposure_set > 0
) us
  ON  aec.cum_exposure_before              < us.exposure_set
  AND aec.cum_exposure_before + aec.era_length >= us.exposure_set;

/*****************************************************************************
 * Step 4 — Final output table
 *****************************************************************************/
DROP TABLE IF EXISTS #exposure_sets;

SELECT person_id, exposure_set, index_date, is_switcher
INTO #exposure_sets
FROM #switcher_sets

UNION ALL

SELECT person_id, exposure_set, index_date, is_switcher
FROM #comparator_sets;

/*****************************************************************************
 * Step 5 — Drop intermediate temp tables
 *****************************************************************************/
DROP TABLE IF EXISTS #switcher_sets;
DROP TABLE IF EXISTS #a_era_cumsum;
DROP TABLE IF EXISTS #comparator_sets;
