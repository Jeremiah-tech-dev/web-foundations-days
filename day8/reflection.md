# Reflection

**The most difficult concept** for me was how data connects in a database,
especially many-to-many relationships. At first I wanted to store a note's
tags as a list in one column. What made it click was building the QuickNotes
tables myself: users, notes, tags and the `note_tags` join table. Then I ran
real queries with JOINs, GROUP BY and LEFT JOIN in SQLite. When "all notes
tagged urgent" returned the right rows, I understood why a join table is
needed. Transactions and constraints made sense the same way. For this
TicketHub design, I could explain double-booking prevention with a UNIQUE
constraint and a row-locking UPDATE instead of just hoping it works.

**In my capstone, StudySprint,** I would first fix the issue found in review:
after a plan is made, the "Hours per day" card shows the plan's total hours.
I would rename the card or show the real daily hours. I would also let
learners tick off finished sessions and save their progress in localStorage,
so the plan becomes a tracker and not only a list. The feedback on my
assignments also taught me to check my submissions: one project was graded on
the wrong repository, and one document was cut off because it was too long.
Now I check the link and keep documents short.

**Next, I want to learn backend development** with Node.js, Express and
PostgreSQL. I will start by replacing the JSONPlaceholder practice API in
QuickNotes with my own API and database, so my designs stop being only on
paper and start running for real.
