/* =====================================================================
   reporting_patterns.sql — Reusable higher-ed reporting patterns.
   Generic schema (see schema.md). No real institution names.
   Grain, definitions, and edge cases are documented per query.
   ===================================================================== */

/* ---------------------------------------------------------------------
   Q1. Cohort definition — Fall 2023 first-time freshman cohort
   Grain: one row per student. This CTE is the denominator for Q3.
   Edge cases: excludes dual-enrolled high-school students and non-degree
   seekers, who would inflate the cohort and depress the rate. Anchored to
   census enrollment in the entry term so summer melt (admitted but never
   enrolled) does not inflate the denominator.
   --------------------------------------------------------------------- */
WITH cohort AS (
    SELECT s.student_id, s.entry_cohort, s.college, s.admit_type
    FROM student s
    WHERE s.entry_cohort = 2023
      AND s.admit_type = 'First-time Freshman'
      AND s.student_type NOT IN ('Dual Enrolled', 'Non-degree')
      AND EXISTS (
          SELECT 1 FROM enrollment e
          WHERE e.student_id = s.student_id
            AND e.term = 'Fall 2023'  -- census enrollment, not just admission
      )
)
SELECT * FROM cohort;


/* ---------------------------------------------------------------------
   Q2. Term-to-term retention by entry cohort
   Grain: one row per cohort × term transition.
   Definition: of students enrolled in term N, % enrolled in term N+1.
   Uses LEAD() over term_seq so "next term" is positional, not calendar.
   --------------------------------------------------------------------- */
WITH ordered AS (
    SELECT
        s.entry_cohort,
        e.student_id,
        e.term_seq,
        LEAD(e.term_seq) OVER (
            PARTITION BY e.student_id ORDER BY e.term_seq
        ) AS next_term_seq
    FROM enrollment e
    JOIN student s USING (student_id)
),
transitions AS (
    SELECT
        entry_cohort,
        term_seq,
        COUNT(*) AS enrolled_n,
        SUM(CASE WHEN next_term_seq = term_seq + 1 THEN 1 ELSE 0 END) AS retained_n
    FROM ordered
    GROUP BY entry_cohort, term_seq
)
SELECT
    entry_cohort,
    term_seq AS from_term,
    term_seq + 1 AS to_term,
    enrolled_n,
    retained_n,
    ROUND(100.0 * retained_n / NULLIF(enrolled_n, 0), 1) AS retention_pct
FROM transitions
ORDER BY entry_cohort, term_seq;


/* ---------------------------------------------------------------------
   Q3. Fall-to-fall retention (the official KPI)
   Grain: one row per cohort.
   Definition (IPEDS-style): % of the fall cohort enrolled the following
   fall, minus standard exclusions. Exclusions are kept visible in the
   SELECT so leadership sees the adjusted denominator. The cohort CTE
   mirrors Q1 (same filters, same census anchor) so the denominator is
   consistent with the published cohort definition.
   --------------------------------------------------------------------- */
WITH cohort AS (
    SELECT s.student_id, s.entry_cohort
    FROM student s
    WHERE s.entry_cohort = 2023
      AND s.admit_type = 'First-time Freshman'
      AND s.student_type NOT IN ('Dual Enrolled', 'Non-degree')
      AND EXISTS (
          SELECT 1 FROM enrollment e
          WHERE e.student_id = s.student_id
            AND e.term = 'Fall 2023'  -- census enrollment, not just admission
      )
),
exclusions AS (
    -- Standard exclusions: deceased, military call-up, church mission.
    SELECT student_id FROM student_exclusion WHERE exclusion_type IN
        ('Deceased', 'Military', 'Religious Mission')
),
retained AS (
    SELECT DISTINCT c.student_id
    FROM cohort c
    JOIN enrollment e USING (student_id)
    WHERE e.term = 'Fall 2024'
)
SELECT
    2023 AS cohort,
    (SELECT COUNT(*) FROM cohort) AS cohort_n,
    (SELECT COUNT(*) FROM exclusions x JOIN cohort c USING (student_id)) AS exclusions_n,
    (SELECT COUNT(*) FROM retained) AS retained_n,
    ROUND(100.0 * (SELECT COUNT(*) FROM retained)
        / NULLIF((SELECT COUNT(*) FROM cohort)
                 - (SELECT COUNT(*) FROM exclusions x JOIN cohort c USING (student_id)), 0), 1
    ) AS fall_to_fall_retention_pct;


/* ---------------------------------------------------------------------
   Q4. DFW rates by college and course level
   Grain: one row per college × course level × term.
   DFW = final grade D, F, or W. Withdrawals count: a W is still an
   unsuccessful outcome for the student, even if GPA-neutral.
   --------------------------------------------------------------------- */
WITH dfw AS (
    SELECT
        college,
        course_level,
        term,
        COUNT(*) AS enrollments_n,
        SUM(CASE WHEN final_grade IN ('D', 'F', 'W') THEN 1 ELSE 0 END) AS dfw_n
    FROM course_enrollment
    WHERE final_grade IS NOT NULL
      AND final_grade NOT IN ('I', 'IP')   -- in-progress grades excluded
    GROUP BY college, course_level, term
)
SELECT
    college, course_level, term,
    enrollments_n, dfw_n,
    ROUND(100.0 * dfw_n / NULLIF(enrollments_n, 0), 1) AS dfw_pct
FROM dfw
ORDER BY term, dfw_pct DESC;


/* ---------------------------------------------------------------------
   Q5. Course outcomes — grade distribution and pass rate by section
   Grain: one row per section. Flags high-DFW sections for review.
   A section with <10 enrollments is suppressed (small-n privacy rule).
   --------------------------------------------------------------------- */
WITH section_stats AS (
    SELECT
        term, course_code, section_id, college,
        COUNT(*) AS enrollments_n,
        SUM(CASE WHEN final_grade IN ('A', 'B') THEN 1 ELSE 0 END) AS ab_n,
        SUM(CASE WHEN final_grade IN ('D', 'F', 'W') THEN 1 ELSE 0 END) AS dfw_n,
        AVG(CASE WHEN final_grade IN ('A','A-') THEN 4.0
                 WHEN final_grade IN ('B+','B','B-') THEN 3.0
                 WHEN final_grade IN ('C+','C','C-') THEN 2.0
                 WHEN final_grade IN ('D+','D','D-') THEN 1.0
                 WHEN final_grade = 'F' THEN 0.0 END) AS avg_gpa_points
    FROM course_enrollment
    WHERE final_grade NOT IN ('I', 'IP', 'W') OR final_grade = 'W'
    GROUP BY term, course_code, section_id, college
)
SELECT
    term, course_code, section_id, college,
    enrollments_n,
    ROUND(100.0 * ab_n / NULLIF(enrollments_n, 0), 1) AS ab_pct,
    ROUND(100.0 * dfw_n / NULLIF(enrollments_n, 0), 1) AS dfw_pct,
    ROUND(avg_gpa_points, 2) AS avg_gpa,
    CASE WHEN dfw_n * 1.0 / NULLIF(enrollments_n, 0) >= 0.30
              AND enrollments_n >= 10
         THEN 'REVIEW' ELSE NULL END AS high_dfw_flag
FROM section_stats
WHERE enrollments_n >= 10          -- small-n suppression
ORDER BY dfw_pct DESC;


/* ---------------------------------------------------------------------
   Q6. Stop-out vs. drop-out — of non-returners, who came back?
   Grain: one row per student who missed a term.
   A "stop-out" re-enrolls within 2 terms; a "drop-out" does not (yet).
   Stop-outs are a re-engagement population, not a loss — report them
   separately or retention work misreads its own funnel.
   --------------------------------------------------------------------- */
WITH terms AS (
    -- Explicit term ordering; never trust alphabetical labels.
    SELECT term, term_order FROM (
        VALUES ('Fall 2022', 1), ('Spring 2023', 2), ('Fall 2023', 3),
               ('Spring 2024', 4), ('Fall 2024', 5), ('Spring 2025', 6)
    ) AS t(term, term_order)
),
enrolled_terms AS (
    SELECT e.student_id, t.term_order
    FROM enrollment e
    JOIN terms t USING (term)
),
missed AS (
    -- Students present in term N but absent in N+1 (and N+1 exists in data)
    SELECT a.student_id, a.term_order AS missed_after
    FROM enrolled_terms a
    WHERE NOT EXISTS (
        SELECT 1 FROM enrolled_terms b
        WHERE b.student_id = a.student_id AND b.term_order = a.term_order + 1
    )
    AND a.term_order < (SELECT MAX(term_order) FROM terms) - 1
)
SELECT
    m.student_id,
    m.missed_after,
    CASE WHEN EXISTS (
        SELECT 1 FROM enrolled_terms r
        WHERE r.student_id = m.student_id
          AND r.term_order IN (m.missed_after + 2, m.missed_after + 3)
    ) THEN 'Stop-out (returned)' ELSE 'Drop-out (not returned)' END AS outcome
FROM missed m
ORDER BY outcome, m.student_id;
