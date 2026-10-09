-- School database: students, courses and enrolments
-- Runs in SQLite (for example sqliteonline.com). Paste the whole file and run it.

PRAGMA foreign_keys = ON; -- SQLite only enforces foreign keys when this is on

-- Start fresh so the file can be run more than once
DROP TABLE IF EXISTS enrolments;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;

-- ---------- Tables ----------

CREATE TABLE students (
  id     INTEGER PRIMARY KEY,
  name   TEXT NOT NULL,
  email  TEXT NOT NULL UNIQUE
);

CREATE TABLE courses (
  id     INTEGER PRIMARY KEY,
  code   TEXT NOT NULL UNIQUE,
  title  TEXT NOT NULL
);

CREATE TABLE enrolments (
  student_id   INTEGER NOT NULL,
  course_id    INTEGER NOT NULL,
  enrolled_on  TEXT NOT NULL DEFAULT CURRENT_DATE,
  grade        INTEGER CHECK (grade BETWEEN 0 AND 100), -- NULL until graded
  PRIMARY KEY (student_id, course_id), -- a student can't enrol on the same course twice
  FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
  FOREIGN KEY (course_id)  REFERENCES courses(id)  ON DELETE CASCADE
);

-- Speeds up "all students on one course" (see school-design.md)
CREATE INDEX idx_enrolments_course ON enrolments (course_id);

-- ---------- Sample data ----------

INSERT INTO students (id, name, email) VALUES
  (1, 'Amina Hassan',   'amina@school.example'),
  (2, 'Brian Otieno',   'brian@school.example'),
  (3, 'Chen Wei',       'chen@school.example'),
  (4, 'Diana Mwangi',   'diana@school.example'); -- not enrolled on anything yet

INSERT INTO courses (id, code, title) VALUES
  (1, 'WEB101',  'Web Foundations'),
  (2, 'DB101',   'Introduction to Databases'),
  (3, 'JS201',   'JavaScript in Depth'),
  (4, 'UX101',   'User Experience Design'); -- no students yet

INSERT INTO enrolments (student_id, course_id, enrolled_on, grade) VALUES
  (1, 1, '2026-09-01', 88),
  (1, 2, '2026-09-01', 74),
  (1, 3, '2026-09-15', NULL),
  (2, 1, '2026-09-02', 91),
  (2, 2, '2026-09-02', NULL),
  (3, 1, '2026-09-03', 67);

-- ---------- Queries ----------

-- 1. All courses for one student (by name)
SELECT courses.code, courses.title, enrolments.grade
FROM enrolments
JOIN students ON students.id = enrolments.student_id
JOIN courses  ON courses.id  = enrolments.course_id
WHERE students.name = 'Amina Hassan'
ORDER BY courses.code;

-- 2. All students on one course
SELECT students.name, students.email, enrolments.grade
FROM enrolments
JOIN students ON students.id = enrolments.student_id
JOIN courses  ON courses.id  = enrolments.course_id
WHERE courses.code = 'WEB101'
ORDER BY students.name;

-- 3. Number of students per course
--    LEFT JOIN keeps courses with no students, so they show 0
SELECT courses.code, courses.title, COUNT(enrolments.student_id) AS student_count
FROM courses
LEFT JOIN enrolments ON enrolments.course_id = courses.id
GROUP BY courses.id
ORDER BY student_count DESC, courses.code;

-- 4. Students who have no enrolments
--    LEFT JOIN gives NULL enrolment columns when there is no match
SELECT students.name, students.email
FROM students
LEFT JOIN enrolments ON enrolments.student_id = students.id
WHERE enrolments.student_id IS NULL;

-- 5. Update one enrolment's grade (Brian's DB101 grade)
UPDATE enrolments
SET grade = 82
WHERE student_id = (SELECT id FROM students WHERE email = 'brian@school.example')
  AND course_id  = (SELECT id FROM courses  WHERE code  = 'DB101');

-- Check the update worked
SELECT students.name, courses.code, enrolments.grade
FROM enrolments
JOIN students ON students.id = enrolments.student_id
JOIN courses  ON courses.id  = enrolments.course_id
WHERE students.email = 'brian@school.example' AND courses.code = 'DB101';
