# Copyright 2026 Observational Health Data Sciences and Informatics
#
# This file is part of PrevalentNewUser
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Six-patient fixture from the PNU design pitch.
#
# Timeline (all on treatment A from observation start):
#
#   Person | A start      | B start (switch) | Exposure set
#   -------|--------------|------------------|-------------
#   1      | 2020-01-01   | 2020-05-01 (~4m) | set 4 (months)
#   2      | 2020-01-01   | 2020-05-01 (~4m) | set 4 (months)
#   3      | 2020-01-01   | 2020-10-01 (~9m) | set 9 (months)
#   4      | 2020-01-01   | never            | comparator
#   5      | 2020-01-01   | never            | comparator
#   6      | 2020-01-01   | never            | comparator
#
# Persons 1-3 are switchers (target). Persons 4-6 are potential comparators.
# Exposure sets are based on time (months) on treatment A at the switch date.
# The comparator index dates for each set are the switcher index dates.
#
# Cohort IDs:
#   treatment_a (reference) cohort_id = 1
#   treatment_b (switcher)  cohort_id = 2
#   outcome                 cohort_id = 3

makeSixPatientFixture <- function() {
  # All persons start A on 2020-01-01; observation window 2019-01-01 to 2022-12-31
  aStart <- as.Date("2020-01-01")

  # Switchers: persons 1 and 2 switch at ~4 months (120 days), person 3 at ~9 months (270 days)
  switch4m <- aStart + 120
  switch9m <- aStart + 270

  treatmentA <- data.frame(
    cohort_definition_id = 1L,
    subject_id = 1:6,
    cohort_start_date = rep(aStart, 6),
    cohort_end_date = c(
      switch4m - 1L, # person 1 ends A when they switch to B
      switch4m - 1L, # person 2
      switch9m - 1L, # person 3
      as.Date("2022-12-31"), # persons 4-6 stay on A
      as.Date("2022-12-31"),
      as.Date("2022-12-31")
    ),
    stringsAsFactors = FALSE
  )

  treatmentB <- data.frame(
    cohort_definition_id = 2L,
    subject_id = c(1L, 2L, 3L),
    cohort_start_date = c(switch4m, switch4m, switch9m),
    cohort_end_date = c(
      as.Date("2022-12-31"),
      as.Date("2022-12-31"),
      as.Date("2022-12-31")
    ),
    stringsAsFactors = FALSE
  )

  observationPeriod <- data.frame(
    person_id = 1:6,
    observation_period_start_date = rep(as.Date("2019-01-01"), 6),
    observation_period_end_date = rep(as.Date("2022-12-31"), 6),
    stringsAsFactors = FALSE
  )

  list(
    treatmentA = treatmentA,
    treatmentB = treatmentB,
    observationPeriod = observationPeriod,
    # Derived constants for use in tests
    switch4m = switch4m,
    switch9m = switch9m,
    aStart = aStart,
    daysAt4m = 120L,
    daysAt9m = 270L
  )
}
