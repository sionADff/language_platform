# language_platform
SQLite database for a Duolingo-style language-learning platform: user accounts and sessions, courses and lessons with ordering, exercises, vocabulary with spaced-repetition fields, progress tracking, achievements and payments. Designed and built as a personal project (2025).

## Tech

- **DBMS:** SQLite 3
- **Language:** SQL

## Schema (14 tables + 1 view)

| Block | Tables |
| --- | --- |
| Users & auth | `roles`, `users`, `user_sessions` |
| Catalog | `languages`, `courses`, `lessons` |
| Content | `vocabulary`, `exercises` |
| Learning state | `user_courses`, `lesson_progress`, `user_vocabulary` |
| Gamification & money | `achievements`, `user_achievements`, `payments` |

Design notes:

- Every enum-like field is protected by `CHECK` constraints (lesson status, exercise type, CEFR level `A1–C2`, payment status) — invalid states are impossible at the database level.
- Composite primary keys for pure many-to-many links (`user_courses`, `user_vocabulary`, `user_achievements`) plus `UNIQUE (user_id, lesson_id)` and `UNIQUE (course_id, position)` to keep data consistent.
- `user_vocabulary.next_review_at` supports spaced repetition (SM-2-style scheduling).
- Indexes on all foreign keys used in lookups (`lessons.course_id`, `lesson_progress.user_id`, etc.).
- `v_course_progress` view computes per-student course completion in percent.
- Only password **hashes** are stored; session tokens are unique and expiring.

## How to run

```bash
sqlite3 language_learning.db < language_learning.sql
sqlite3 language_learning.db
```

Inside the shell check that foreign keys are enforced and the view works:

```sql
PRAGMA foreign_keys = ON;
SELECT * FROM v_course_progress;
```

The script creates the schema, indexes, the view and demo data: 4 users, 3 courses, 7 lessons, 8 vocabulary items, exercises, progress rows, achievements and 3 payments.

## Example queries

**1. Course progress per student (view):**

```sql
SELECT * FROM v_course_progress;
```

**2. Revenue per paid course:**

```sql
SELECT c.title,
       COUNT(p.payment_id)        AS sales,
       ROUND(SUM(p.amount_usd), 2) AS revenue_usd
FROM payments p
JOIN courses c ON c.course_id = p.course_id
WHERE p.status = 'paid'
GROUP BY c.course_id;
```

**3. Leaderboard: completed lessons and learned words:**

```sql
SELECT u.username,
       SUM(CASE WHEN lp.status = 'completed' THEN 1 ELSE 0 END) AS lessons_completed,
       SUM(uv.is_learned)                                        AS words_learned
FROM users u
LEFT JOIN lesson_progress lp ON lp.user_id = u.user_id
LEFT JOIN user_vocabulary uv ON uv.user_id = u.user_id
WHERE u.role_id = 1
GROUP BY u.user_id
ORDER BY lessons_completed DESC;
```

**4. Vocabulary difficulty distribution per language:**

```sql
SELECT l.name, v.difficulty, COUNT(*) AS words
FROM vocabulary v
JOIN languages l ON l.language_id = v.language_id
GROUP BY l.name, v.difficulty
ORDER BY l.name, v.difficulty;
```

**5. Paid but not activated — churn candidates (NOT EXISTS):**

```sql
SELECT u.username, c.title
FROM payments p
JOIN users u   ON u.user_id = p.user_id
JOIN courses c ON c.course_id = p.course_id
WHERE p.status = 'paid'
  AND NOT EXISTS (
        SELECT 1
        FROM lesson_progress lp
        JOIN lessons l ON l.lesson_id = lp.lesson_id
        WHERE lp.user_id = u.user_id AND l.course_id = c.course_id
          AND lp.status = 'completed'
  );
```

## Project status

Schema, indexes, view and seed data are complete; application backend is out of scope for this repository.
