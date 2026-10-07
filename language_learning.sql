

-- 1. Users & authentication
CREATE TABLE roles (
    role_id   INTEGER PRIMARY KEY,
    role_name TEXT NOT NULL UNIQUE            -- 'student', 'teacher', 'admin'
);

CREATE TABLE users (
    user_id       INTEGER PRIMARY KEY,
    username      TEXT NOT NULL UNIQUE,
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role_id       INTEGER NOT NULL REFERENCES roles(role_id),
    native_lang   TEXT DEFAULT 'ru',
    avatar_url    TEXT,
    is_active     INTEGER NOT NULL DEFAULT 1,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_sessions (
    session_id INTEGER PRIMARY KEY,
    user_id    INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token      TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    ip_address TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Languages & courses
CREATE TABLE languages (
    language_id INTEGER PRIMARY KEY,
    code        TEXT NOT NULL UNIQUE,       -- 'en', 'de', 'fr'
    name        TEXT NOT NULL,
    flag_emoji  TEXT
);

CREATE TABLE courses (
    course_id   INTEGER PRIMARY KEY,
    language_id INTEGER NOT NULL REFERENCES languages(language_id),
    title       TEXT NOT NULL,
    description TEXT,
    level       TEXT CHECK (level IN ('A1','A2','B1','B2','C1','C2')),
    price_usd   REAL DEFAULT 0,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE lessons (
    lesson_id    INTEGER PRIMARY KEY,
    course_id    INTEGER NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE,
    title        TEXT NOT NULL,
    content      TEXT,
    duration_min INTEGER NOT NULL DEFAULT 15,
    position     INTEGER NOT NULL,          -- порядок урока в курсе
    is_free      INTEGER NOT NULL DEFAULT 0,
    UNIQUE (course_id, position)
);

-- 3. Learning content
CREATE TABLE vocabulary (
    word_id     INTEGER PRIMARY KEY,
    language_id INTEGER NOT NULL REFERENCES languages(language_id),
    word        TEXT NOT NULL,
    translation TEXT NOT NULL,
    example     TEXT,
    difficulty  INTEGER NOT NULL DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 5)
);

CREATE TABLE exercises (
    exercise_id    INTEGER PRIMARY KEY,
    lesson_id      INTEGER NOT NULL REFERENCES lessons(lesson_id) ON DELETE CASCADE,
    type           TEXT NOT NULL CHECK (type IN ('multiple_choice','translate','listen','match')),
    question       TEXT NOT NULL,
    correct_answer TEXT NOT NULL,
    options        TEXT,                    -- JSON-варианты ответов
    xp_reward      INTEGER NOT NULL DEFAULT 10
);

-- 4. User learning state
CREATE TABLE user_courses (
    user_id     INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    course_id   INTEGER NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE,
    enrolled_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, course_id)
);

CREATE TABLE lesson_progress (
    progress_id  INTEGER PRIMARY KEY,
    user_id      INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    lesson_id    INTEGER NOT NULL REFERENCES lessons(lesson_id) ON DELETE CASCADE,
    status       TEXT NOT NULL DEFAULT 'not_started'
                 CHECK (status IN ('not_started','in_progress','completed')),
    score_pct    INTEGER CHECK (score_pct BETWEEN 0 AND 100),
    completed_at TIMESTAMP,
    UNIQUE (user_id, lesson_id)
);

CREATE TABLE user_vocabulary (
    user_id        INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    word_id        INTEGER NOT NULL REFERENCES vocabulary(word_id) ON DELETE CASCADE,
    times_reviewed INTEGER NOT NULL DEFAULT 0,
    is_learned     INTEGER NOT NULL DEFAULT 0,
    next_review_at TIMESTAMP,               -- для интервальных повторений
    PRIMARY KEY (user_id, word_id)
);

-- 5. Gamification & monetisation
CREATE TABLE achievements (
    achievement_id INTEGER PRIMARY KEY,
    code           TEXT NOT NULL UNIQUE,    -- 'first_lesson', 'streak_7'
    title          TEXT NOT NULL,
    xp_reward      INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE user_achievements (
    user_id        INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    achievement_id INTEGER NOT NULL REFERENCES achievements(achievement_id),
    unlocked_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE payments (
    payment_id INTEGER PRIMARY KEY,
    user_id    INTEGER NOT NULL REFERENCES users(user_id),
    course_id  INTEGER NOT NULL REFERENCES courses(course_id),
    amount_usd REAL NOT NULL,
    status     TEXT NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending','paid','refunded','failed')),
    paid_at    TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_lessons_course   ON lessons(course_id);
CREATE INDEX idx_exercises_lesson ON exercises(lesson_id);
CREATE INDEX idx_progress_user    ON lesson_progress(user_id);
CREATE INDEX idx_sessions_user    ON user_sessions(user_id);
CREATE INDEX idx_vocab_language   ON vocabulary(language_id);

-- View: student course progress (%)
CREATE VIEW v_course_progress AS
SELECT u.username,
       c.title AS course,
       COUNT(DISTINCT l.lesson_id) AS total_lessons,
       SUM(CASE WHEN lp.status = 'completed' THEN 1 ELSE 0 END) AS completed_lessons,
       ROUND(100.0 * SUM(CASE WHEN lp.status = 'completed' THEN 1 ELSE 0 END)
             / COUNT(DISTINCT l.lesson_id), 0) AS progress_pct
FROM users u
JOIN user_courses uc ON uc.user_id = u.user_id
JOIN courses c       ON c.course_id = uc.course_id
JOIN lessons l       ON l.course_id = c.course_id
LEFT JOIN lesson_progress lp ON lp.lesson_id = l.lesson_id AND lp.user_id = u.user_id
GROUP BY u.user_id, c.course_id;

-- ============================================================
-- Seed data (demo users, hashes are placeholders)
-- ============================================================
INSERT INTO roles (role_id, role_name) VALUES
    (1, 'student'), (2, 'teacher'), (3, 'admin');

INSERT INTO languages (language_id, code, name, flag_emoji) VALUES
    (1, 'en', 'English', '🇬🇧'),
    (2, 'de', 'German',  '🇩🇪'),
    (3, 'es', 'Spanish', '🇪🇸');

INSERT INTO users (user_id, username, email, password_hash, role_id, native_lang) VALUES
    (1, 'dana_learns',  'dana@example.com',  'hash_demo_1', 1, 'ru'),
    (2, 'temirlan_en',  'temir@example.com', 'hash_demo_2', 1, 'kk'),
    (3, 'teacher_ann',  'ann@example.com',   'hash_demo_3', 2, 'en'),
    (4, 'platform_admin','admin@example.com','hash_demo_4', 3, 'ru');

INSERT INTO courses (course_id, language_id, title, description, level, price_usd) VALUES
    (1, 1, 'English A1 Starter',   'Basics: alphabet, greetings, numbers.',        'A1', 0),
    (2, 1, 'English B1 Grammar',   'Tenses, modal verbs, conditionals.',           'B1', 19.99),
    (3, 2, 'German A1 Starter',    'Basics: cases, articles, everyday phrases.',   'A1', 14.99);

INSERT INTO lessons (lesson_id, course_id, title, content, duration_min, position, is_free) VALUES
    (1, 1, 'Greetings',          'Hello, hi, goodbye...',        10, 1, 1),
    (2, 1, 'Numbers 1-20',       'Counting and spelling.',       15, 2, 1),
    (3, 1, 'Family members',     'Mother, father, sister...',    20, 3, 0),
    (4, 2, 'Present Perfect',    'Form and usage.',              25, 1, 0),
    (5, 2, 'Conditionals',       'If-clauses type 1 and 2.',     30, 2, 0),
    (6, 3, 'Der, die, das',      'German articles.',             15, 1, 1),
    (7, 3, 'Personal pronouns',  'Ich, du, er, sie, es.',        15, 2, 0);

INSERT INTO vocabulary (word_id, language_id, word, translation, example, difficulty) VALUES
    (1, 1, 'apple',      'яблоко',    'I eat an apple.',              1),
    (2, 1, 'journey',    'путешествие','The journey was long.',       2),
    (3, 1, 'accomplish', 'выполнять', 'She accomplished her goal.',   4),
    (4, 1, 'serendipity','удачная находка','It was pure serendipity.',5),
    (5, 2, 'Haus',       'дом',       'Das Haus ist groß.',           1),
    (6, 2, 'Wissen',     'знание',    'Wissen ist Macht.',            3),
    (7, 3, 'gato',       'кот',       'El gato duerme.',              1),
    (8, 3, 'desarrollar','развивать', 'Quiero desarrollar ideas.',    4);

INSERT INTO exercises (exercise_id, lesson_id, type, question, correct_answer, options, xp_reward) VALUES
    (1, 1, 'multiple_choice', 'Choose the correct greeting',           'Hello',      '["Hello","Goodbye","Thanks"]',      10),
    (2, 1, 'translate',       'Translate: "спасибо"',                  'thank you',  NULL,                                15),
    (3, 2, 'match',           'Match numbers and words',               '1-one',      '["1-one","2-two","3-three"]',       10),
    (4, 4, 'multiple_choice', 'Present Perfect of "to go"',            'have gone',  '["have gone","goes","going"]',      20);

INSERT INTO user_courses (user_id, course_id) VALUES
    (1, 1), (1, 2), (2, 1), (2, 3);

INSERT INTO lesson_progress (user_id, lesson_id, status, score_pct, completed_at) VALUES
    (1, 1, 'completed', 100, '2025-11-02 10:00:00'),
    (1, 2, 'completed',  85, '2025-11-03 18:30:00'),
    (1, 3, 'in_progress',NULL, NULL),
    (1, 4, 'completed',  70, '2025-11-05 20:00:00'),
    (2, 1, 'completed',  95, '2025-11-01 09:00:00'),
    (2, 2, 'not_started',NULL, NULL),
    (2, 6, 'completed',  90, '2025-11-04 12:00:00');

INSERT INTO user_vocabulary (user_id, word_id, times_reviewed, is_learned, next_review_at) VALUES
    (1, 1, 5, 1, '2025-11-10 08:00:00'),
    (1, 2, 3, 1, '2025-11-08 08:00:00'),
    (1, 3, 1, 0, '2025-11-06 08:00:00'),
    (2, 1, 4, 1, '2025-11-09 08:00:00'),
    (2, 5, 2, 0, '2025-11-07 08:00:00');

INSERT INTO achievements (achievement_id, code, title, xp_reward) VALUES
    (1, 'first_lesson', 'First steps',      50),
    (2, 'streak_7',     'Week on fire',    200),
    (3, 'words_100',    'Vocabulary hunter',300);

INSERT INTO user_achievements (user_id, achievement_id) VALUES
    (1, 1), (2, 1);

INSERT INTO payments (payment_id, user_id, course_id, amount_usd, status, paid_at) VALUES
    (1, 1, 2, 19.99, 'paid',    '2025-11-02 10:05:00'),
    (2, 2, 3, 14.99, 'paid',    '2025-11-01 09:05:00'),
    (3, 2, 2, 19.99, 'pending', NULL);

-- ============================================================
-- Example analytical queries
-- ============================================================

-- 1. Course progress for every student (uses the v_course_progress view)
SELECT * FROM v_course_progress;

-- 2. Revenue per paid course
SELECT c.title,
       COUNT(p.payment_id)       AS sales,
       ROUND(SUM(p.amount_usd),2) AS revenue_usd
FROM payments p
JOIN courses c ON c.course_id = p.course_id
WHERE p.status = 'paid'
GROUP BY c.course_id;

-- 3. Leaderboard: completed lessons and learned words per student
SELECT u.username,
       SUM(CASE WHEN lp.status = 'completed' THEN 1 ELSE 0 END) AS lessons_completed,
       SUM(uv.is_learned)                                        AS words_learned
FROM users u
LEFT JOIN lesson_progress lp ON lp.user_id = u.user_id
LEFT JOIN user_vocabulary uv ON uv.user_id = u.user_id
WHERE u.role_id = 1
GROUP BY u.user_id
ORDER BY lessons_completed DESC;

-- 4. Vocabulary difficulty distribution per language
SELECT l.name, v.difficulty, COUNT(*) AS words
FROM vocabulary v
JOIN languages l ON l.language_id = v.language_id
GROUP BY l.name, v.difficulty
ORDER BY l.name, v.difficulty;

-- 5. Students with a paid course but zero completed lessons
--    (activation funnel: potential churn)
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
