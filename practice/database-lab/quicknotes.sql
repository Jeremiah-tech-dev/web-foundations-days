-- QuickNotes database lab
-- Paste the whole file into sqliteonline.com and run it.

PRAGMA foreign_keys = ON; -- SQLite only enforces foreign keys when this is on

-- Start fresh so the file can be run more than once
DROP TABLE IF EXISTS note_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS notes;
DROP TABLE IF EXISTS users;

-- ---------- Tables ----------

CREATE TABLE users (
  id          INTEGER PRIMARY KEY,
  name        TEXT NOT NULL,
  email       TEXT NOT NULL UNIQUE,
  created_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notes (
  id          INTEGER PRIMARY KEY,
  user_id     INTEGER NOT NULL,
  text        TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE tags (
  id    INTEGER PRIMARY KEY,
  name  TEXT NOT NULL UNIQUE
);

CREATE TABLE note_tags (
  note_id  INTEGER NOT NULL,
  tag_id   INTEGER NOT NULL,
  PRIMARY KEY (note_id, tag_id),   -- the same pair cannot appear twice
  FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id)  REFERENCES tags(id)  ON DELETE CASCADE
);

-- ---------- Indexes ----------

-- Finds one user's notes and returns them already sorted by date
CREATE INDEX idx_notes_user_created ON notes (user_id, created_at);

-- Finds every note that has a given tag
CREATE INDEX idx_note_tags_tag ON note_tags (tag_id);

-- ---------- Sample data ----------

INSERT INTO users (id, name, email) VALUES
  (1, 'Amina', 'amina@example.com'),
  (2, 'Brian', 'brian@example.com'),
  (3, 'Chen',  'chen@example.com');   -- Chen has no notes yet

INSERT INTO notes (id, user_id, text, created_at) VALUES
  (1, 1, 'Revise chapter 3 for the exam', '2026-10-01 09:00:00'),
  (2, 1, 'Pay the electricity bill',      '2026-10-03 18:30:00'),
  (3, 1, 'Call the landlord',             '2026-10-05 08:15:00'),
  (4, 2, 'Submit the Day 5 assignment',   '2026-10-04 20:00:00'),
  (5, 2, 'Buy groceries',                 '2026-10-06 12:00:00');

INSERT INTO tags (id, name) VALUES
  (1, 'urgent'),
  (2, 'study'),
  (3, 'home');

INSERT INTO note_tags (note_id, tag_id) VALUES
  (1, 2),   -- exam revision: study
  (2, 1),   -- electricity bill: urgent
  (2, 3),   -- electricity bill: home
  (3, 3),   -- landlord: home
  (4, 1),   -- Day 5 assignment: urgent
  (4, 2);   -- Day 5 assignment: study

-- ---------- Queries ----------

-- 1. All of Amina's notes, newest first
SELECT notes.id, notes.text, notes.created_at
FROM notes
JOIN users ON users.id = notes.user_id
WHERE users.name = 'Amina'
ORDER BY notes.created_at DESC;

-- 2. All notes tagged "urgent" (two JOINs)
SELECT notes.id, notes.text
FROM notes
JOIN note_tags ON note_tags.note_id = notes.id
JOIN tags      ON tags.id = note_tags.tag_id
WHERE tags.name = 'urgent';

-- 3. How many notes each user has
SELECT users.name, COUNT(notes.id) AS note_count
FROM users
LEFT JOIN notes ON notes.user_id = users.id
GROUP BY users.id
ORDER BY note_count DESC;
