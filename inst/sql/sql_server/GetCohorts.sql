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

/*****************************************************************************
 * Step 1 — Combine switchers and comparators with their cohort end dates.
 *
 * The INTO clause applies to the entire UNION ALL result; it must appear
 * only once, in the first SELECT.
 *
 * Switchers   (is_switcher = 1): join to the B cohort on (person, B start)
 *             to recover cohort_end_date; treatment = 1.
 *
 * Comparators (is_switcher = 0): join to the A cohort on the era that
 *             contains the comparator's index_date; treatment = 0.
 *****************************************************************************/
DROP TABLE IF EXISTS #pnu_raw;

SELECT
  b.subject_id                          AS subject_id,
  CAST(b.subject_id AS VARCHAR(30))     AS person_id,
  e.index_date                          AS cohort_start_date,
  b.cohort_end_date,
  CAST(1 AS INT)                        AS treatment,
  CAST(e.exposure_set AS INT)           AS exposure_set_id
INTO #pnu_raw
FROM #exposure_sets e
INNER JOIN @cohort_database_schema.@cohort_table b
  ON  CAST(b.subject_id AS VARCHAR(30)) = e.person_id
  AND b.cohort_definition_id            = @comparator_cohort_id
  AND b.cohort_start_date               = e.index_date
WHERE e.is_switcher = 1

UNION ALL

SELECT
  a.subject_id                          AS subject_id,
  CAST(a.subject_id AS VARCHAR(30))     AS person_id,
  e.index_date                          AS cohort_start_date,
  a.cohort_end_date,
  CAST(0 AS INT)                        AS treatment,
  CAST(e.exposure_set AS INT)           AS exposure_set_id
FROM #exposure_sets e
INNER JOIN @cohort_database_schema.@cohort_table a
  ON  CAST(a.subject_id AS VARCHAR(30)) = e.person_id
  AND a.cohort_definition_id            = @target_cohort_id
  AND a.cohort_start_date              <= e.index_date
  AND a.cohort_end_date                >= e.index_date
WHERE e.is_switcher = 0;

/*****************************************************************************
 * Step 2 — Assign row_id (unique per row) and person_seq_id (unique per person)
 *****************************************************************************/
DROP TABLE IF EXISTS #pnu_cohorts;

SELECT
  ROW_NUMBER() OVER (ORDER BY subject_id, exposure_set_id, treatment) AS row_id,
  DENSE_RANK()  OVER (ORDER BY subject_id)                            AS person_seq_id,
  subject_id,
  person_id,
  cohort_start_date,
  cohort_end_date,
  treatment,
  exposure_set_id
INTO #pnu_cohorts
FROM #pnu_raw;

DROP TABLE IF EXISTS #pnu_raw;
