# School Database Design

The SQL is in [school.sql](school.sql).

## Tables

### students

One row per student.

- `id` (INTEGER): **primary key**
- `name` (TEXT, NOT NULL)
- `email` (TEXT, NOT NULL, **UNIQUE**): two students can't share an email

### courses

One row per course.

- `id` (INTEGER): **primary key**
- `code` (TEXT, NOT NULL, UNIQUE): for example `WEB101`
- `title` (TEXT, NOT NULL)

### enrolments

One row for each time a student enrols on a course. It links the other two
tables and holds the facts that belong to that pairing, not to the student or
the course alone.

- `student_id` (INTEGER, NOT NULL): **foreign key** → `students.id`
- `course_id` (INTEGER, NOT NULL): **foreign key** → `courses.id`
- `enrolled_on` (TEXT, NOT NULL): defaults to today's date
- `grade` (INTEGER, 0–100): empty (NULL) until the course is graded

The **primary key is the pair `(student_id, course_id)`**, so the database
rejects a second enrolment of the same student on the same course.
`ON DELETE CASCADE` removes a student's or course's enrolments when that
student or course is deleted.

## Relationships

```
students 1 ──< enrolments >── 1 courses
```

- **students → enrolments: one-to-many.** One student can have many
  enrolments, and each enrolment belongs to one student.
- **courses → enrolments: one-to-many.** One course can have many
  enrolments, and each enrolment is for one course.
- **students ↔ courses: many-to-many.** A student takes many courses and a
  course has many students. Together, the two one-to-many relationships above
  make this many-to-many relationship.

**Why a join table is needed:** a many-to-many relationship can't be stored
with a single foreign key. A `course_id` column in `students` would allow only
one course per student. A list such as `"WEB101,DB101"` in one column would be
hard to search, count and update, and the database couldn't check it. The
`enrolments` join table stores one row per student–course pair. It is also the
natural place for the grade, because a grade belongs to one student on one
course.

## Index

```sql
CREATE INDEX idx_enrolments_course ON enrolments (course_id);
```

"Which students are on this course?" is a common query, for class lists and
for counting students per course. It searches `enrolments` by `course_id`. The
primary key `(student_id, course_id)` starts with `student_id`, so it already
speeds up searches by student but not by course. Without this index, the
database would have to read every enrolment row to find one course's students.
The index costs a little extra storage and makes inserts slightly slower, which
is worth it because enrolments are read far more often than they are written.

## SQL or NoSQL?

I would choose **SQL** for this system. The data has a fixed, predictable
structure (every student has a name and email, every course has a code and
title), and it is built around relationships: the core question is which
students are on which courses. A relational database handles this directly
with foreign keys, JOINs and GROUP BY, and it enforces the rules itself. It
rejects duplicate emails, double enrolments and grades outside 0–100, and it
won't let an enrolment point to a student who doesn't exist. Grades also need
to be accurate, so SQL's transactions are useful when several changes must
succeed or fail together. A document (NoSQL) database could store each student
with their courses nested inside, but then course details would be copied into
many student documents, and "all students on a course" would mean searching
through every student. NoSQL suits data whose shape varies a lot or which
doesn't need many links between records, and that doesn't describe a school's
enrolment records.
