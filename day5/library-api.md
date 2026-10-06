# Library API Design: Books

A REST API for a library's `books` resource. The resource is a plural noun,
and the HTTP method says what to do with it.

- **Base URL:** `https://api.example-library.com`
- **Format:** requests and responses use JSON (`Content-Type: application/json`)

## The book resource

```json
{
  "id": 42,
  "title": "Things Fall Apart",
  "author": "Chinua Achebe",
  "year": 1958,
  "isbn": "9780385474542",
  "available": true
}
```

- `id` is assigned by the server.
- `title` and `author` are required when creating a book.

## Endpoints

### 1. List all books

- **Method:** `GET`
- **Path:** `/books`
- **Description:** Returns an array of every book in the library.
- **Request body:** none
- **Success status:** `200 OK`

### 2. Get one book

- **Method:** `GET`
- **Path:** `/books/{id}` (example: `/books/42`)
- **Description:** Returns the single book with the given id.
- **Request body:** none
- **Success status:** `200 OK`

### 3. Create a book

- **Method:** `POST`
- **Path:** `/books`
- **Description:** Adds a new book and returns it with its new `id`.
- **Example request body:**

  ```json
  {
    "title": "Half of a Yellow Sun",
    "author": "Chimamanda Ngozi Adichie",
    "year": 2006,
    "isbn": "9780007200283"
  }
  ```

- **Success status:** `201 Created`

### 4. Update a book

- **Method:** `PATCH`
- **Path:** `/books/{id}` (example: `/books/42`)
- **Description:** Changes only the fields sent and returns the updated book.
- **Example request body:**

  ```json
  {
    "available": false
  }
  ```

- **Success status:** `200 OK`

### 5. Delete a book

- **Method:** `DELETE`
- **Path:** `/books/{id}` (example: `/books/42`)
- **Description:** Removes the book from the library.
- **Request body:** none
- **Success status:** `204 No Content`

### 6. List books by an author

- **Method:** `GET`
- **Path:** `/books?author={name}` (example: `/books?author=Chinua%20Achebe`)
- **Description:** Returns only the books written by the given author.
- **Request body:** none
- **Success status:** `200 OK` (an empty array `[]` if the author has no books)

## Error codes

### 400 Bad Request

The client sent data the server cannot accept.

- **Example:** `POST /books` with a body that has no `title`:

  ```json
  { "author": "Chinua Achebe" }
  ```

- **Example response:**

  ```json
  { "error": "title is required" }
  ```

### 404 Not Found

The requested book does not exist.

- **Example:** `GET /books/9999` when no book has id `9999`
  (the same applies to `PATCH` or `DELETE` on that id).
- **Example response:**

  ```json
  { "error": "Book 9999 not found" }
  ```
