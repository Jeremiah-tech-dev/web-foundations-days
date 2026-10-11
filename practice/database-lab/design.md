# QuickNotes Database Design

The runnable SQL is in [quicknotes.sql](quicknotes.sql).

## 1. Entities

- **users**: the people who write notes
- **notes**: the notes themselves
- **tags**: labels such as `urgent`, `study` and `home`
- **note_tags**: a join table that links notes to tags

## 2. Columns

PK = primary key, FK = foreign key.

### users

| Column       | Type    | Notes                         |
| ------------ | ------- | ----------------------------- |
| `id`         | INTEGER | **PK**                        |
| `name`       | TEXT    | required                      |
| `email`      | TEXT    | required, unique              |
| `created_at` | TEXT    | defaults to the current time  |

### notes

| Column       | Type    | Notes                                |
| ------------ | ------- | ------------------------------------ |
| `id`         | INTEGER | **PK**                               |
| `user_id`    | INTEGER | **FK** → `users.id`, required        |
| `text`       | TEXT    | required                             |
| `created_at` | TEXT    | defaults to the current time         |

### tags

| Column | Type    | Notes            |
| ------ | ------- | ---------------- |
| `id`   | INTEGER | **PK**           |
| `name` | TEXT    | required, unique |

### note_tags

| Column    | Type    | Notes                |
| --------- | ------- | -------------------- |
| `note_id` | INTEGER | **FK** → `notes.id`  |
| `tag_id`  | INTEGER | **FK** → `tags.id`   |

The primary key is the pair `(note_id, tag_id)`, so the same tag can't be
attached to the same note twice.

SQLite has no separate date type, so dates are stored as TEXT in the format
`YYYY-MM-DD HH:MM:SS`. Text in that format sorts in date order.

## 3. Relationships

```
users 1 ──────< notes >──────< tags
           (one-to-many)   (many-to-many,
                            through note_tags)

users.id  ──<  notes.user_id
notes.id  ──<  note_tags.note_id
tags.id   ──<  note_tags.tag_id
```

- **users → notes: one-to-many.** One user has many notes, and each note
  belongs to exactly one user. A foreign key `notes.user_id` stores which user
  owns the note.
- **notes ↔ tags: many-to-many.** A note can have many tags, and a tag can be
  on many notes. One foreign key can't hold that, so the `note_tags` join table
  stores one row per note–tag pair.
- **ON DELETE CASCADE:** deleting a user deletes their notes, and deleting a
  note or a tag deletes its rows in `note_tags`.

## 4. Indexes

| Index                                | Why                                                                                                                                                                                 |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `notes (user_id, created_at)`        | Loading one user's notes, newest first, is the most common query in the app. This index finds that user's notes directly and keeps them in date order, so no separate sort is needed. |
| `note_tags (tag_id)`                 | The "tagged urgent" query looks up rows by `tag_id`. The primary key `(note_id, tag_id)` starts with `note_id`, so it can't help with that.                                          |

These columns are already indexed, so they don't need another one:

- **Primary keys** (`users.id`, `notes.id`, `tags.id`) are indexed automatically.
- **UNIQUE columns** (`users.email`, `tags.name`) get an index automatically.
- **`note_tags (note_id, tag_id)`**: the composite primary key covers lookups by
  `note_id`, such as "which tags does this note have?"

**Not indexed: `users.name`.** The lab looks Amina up by name, but a real app
would use the logged-in user's `id`. Names aren't unique, and every index slows
down writes a little and takes extra space, so only columns that queries
actually search on get one.
