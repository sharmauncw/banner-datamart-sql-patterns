# Assumed Schema (generic higher-ed datamart)

All queries in `reporting_patterns.sql` assume these structures. Adapt names to your warehouse.

## student

| Column | Type | Notes |
|---|---|---|
| `student_id` | varchar | Surrogate key, stable across terms |
| `entry_term` | varchar | e.g. `'Fall 2023'` — first term of enrollment |
| `entry_cohort` | int | e.g. `2023` — entry year, never re-derived |
| `admit_type` | varchar | `'First-time Freshman'`, `'Transfer'`, … |
| `college` | varchar | College of primary major at entry |
| `first_gen_flag` | boolean | |
| `pell_flag` | boolean | |

## enrollment (student-term grain)

| Column | Type | Notes |
|---|---|---|
| `student_id` | varchar | FK → student |
| `term` | varchar | e.g. `'Fall 2023'` |
| `term_seq` | int | 1, 2, 3… from the student's entry term |
| `enrolled_flag` | boolean | True if enrolled (only enrolled rows stored) |
| `term_gpa` | numeric | Nullable (e.g. all-withdrawn terms) |
| `credits_attempted` | int | |
| `credits_earned` | int | |

## course_enrollment (student-course grain)

| Column | Type | Notes |
|---|---|---|
| `student_id` | varchar | |
| `term` | varchar | |
| `course_code` | varchar | e.g. `'ENG 101'` |
| `section_id` | varchar | |
| `college` | varchar | College offering the course |
| `course_level` | varchar | `'Lower'` (100/200) or `'Upper'` (300/400) |
| `final_grade` | varchar | `'A'`, `'B'`, …, `'F'`, `'W'`, `'I'` |
| `credits` | int | |

## Conventions used in the queries

- **Cohort = entry cohort.** Always from `student.entry_cohort`, never inferred from activity.
- **Retention denominators** exclude students confirmed deceased or called to military service (the standard IPEDS exclusions), shown as a CTE for visibility.
- **DFW** = final grade in (`'D'`, `'F'`, `'W'`). Some shops include `'I'`; adjust the CTE.
- **Term ordering** uses an explicit `term_order` mapping CTE — never rely on alphabetical term labels.
