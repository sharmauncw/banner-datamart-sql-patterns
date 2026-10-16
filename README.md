# Banner-Style Datamart SQL Patterns

Sanitized, reusable SQL patterns for the reporting logic every institutional research shop rebuilds: cohort definitions, term-to-term retention, DFW rates, and course outcomes.

- **Generic schema.** Table and column names follow common higher-ed warehouse conventions (`student`, `enrollment`, `course_section`). No real institution names, no vendor-proprietary objects.
- **Commented like production code.** Each query states its grain, its definitions, and its edge cases — because the next analyst inherits your WHERE clause.
- **Dialect:** standard SQL (tested mentally against Postgres/Snowflake/Trino). Window functions used throughout.

## Query index

| # | Query | Answers |
|---|---|---|
| 1 | `cohort_definition` | Who is in the Fall 2023 first-time freshman cohort? |
| 2 | `term_to_term_retention` | What % persisted from each term to the next, by cohort? |
| 3 | `fall_to_fall_retention` | The official retention KPI: fall entrants enrolled next fall. |
| 4 | `dfw_rates` | D/F/Withdraw rates by college and course level. |
| 5 | `course_outcomes` | Grade distribution and pass rates by course section. |
| 6 | `stopout_vs_dropout` | Of non-returners, who came back within 2 terms? |

See `schema.md` for the assumed table structures, then `reporting_patterns.sql`.
