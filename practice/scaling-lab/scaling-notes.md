# Scaling QuickNotes to 1 Million Users

Diagram: [quicknotes-1m.excalidraw](quicknotes-1m.excalidraw) (open at
excalidraw.com → menu → Open). Image: [quicknotes-1m.png](quicknotes-1m.png).

## Stage 1: one server

One machine runs the web server, the app code and the database.

**Its two biggest problems:**

1. **Single point of failure.** If that one server crashes or is restarted
   for an update, QuickNotes is down for everyone.
2. **It can't grow past one machine.** The app and the database compete for
   the same CPU, memory and disk. Once traffic is higher than that machine can
   handle, everything slows down, and a bigger machine only delays the problem.

## Adding components, one at a time

| # | Component | Problem it solves |
|---|-----------|-------------------|
| 1 | **Separate database server** | The app and database stop competing for one machine's CPU, memory and disk, so each can be sized for its own job. |
| 2 | **Load balancer + 2–3 app servers** | One server is no longer a single point of failure, and more servers can be added as traffic grows. This works because the app servers are stateless, so any one can handle any request. |
| 3 | **DNS** | Users type `quicknotes.com` instead of an IP address, and the IP behind the name can change without anyone noticing. |
| 4 | **CDN** | Static files (HTML, CSS, JS, images) are served from a location close to each user, so pages load faster and app servers only handle API calls. |
| 5 | **Cache (Redis)** | Popular reads, like a user's note list, come from memory instead of the database. That makes them faster and takes most read load off the database. |
| 6 | **Read replicas** | Reads that the cache misses are spread over copies of the database, so the primary only has to handle writes. |
| 7 | **Message queue + worker** | Slow jobs (emails, exports, updating the search index) run in the background, so the user's request returns straight away instead of waiting for them. |

## Request paths (arrows on the diagram)

**(a) Loading the page** (blue)
1. The browser asks **DNS** for the IP address of `quicknotes.com`.
2. The browser downloads HTML, CSS and JS from the nearest **CDN** location.
   No app server or database is involved.

**(b) GET /notes** (green)
1. The browser sends `GET /notes` to the **load balancer**.
2. The load balancer passes it to any **app server** (App 2 in the diagram).
3. The app checks the **cache**. If the note list is there, it returns it.
4. If not, the app reads from a **read replica**, saves the result in the
   cache for next time, and returns it.

**(c) POST /notes** (red)
1. The browser sends `POST /notes` to the **load balancer**.
2. The load balancer passes it to any **app server** (App 3 in the diagram).
3. The app `INSERT`s the note into the **primary database**. The primary then
   copies the change to the replicas (grey dashed arrow).
4. The app **deletes that user's cached note list** so the next GET doesn't
   return an old list.
5. The app adds a job to the **message queue** (for example "update search
   index") and returns `201 Created` straight away.
6. A **worker** picks up the job and does it in the background.

## Load estimate

**Replace these with your Part 2 numbers if they differ.** These are our own
assumptions:

| | Calculation | Result |
|---|---|---|
| Daily active users | 1,000,000 × 20% | 200,000 |
| Reads per day | 200,000 × 20 | 4,000,000 ≈ **46/s** average, **~500/s** at peak (10×) |
| Writes per day | 200,000 × 2 | 400,000 ≈ **5/s** average, **~50/s** at peak |
| New storage | 400,000 notes × 1 KB × 365 | **~150 GB/year** |

**What it tells us:** there are about 10 times more reads than writes, so most
of the design (CDN, cache, read replicas) is about making reads cheap. One
primary database can easily handle ~50 writes per second.

## Trade-off to present

**Read replicas make reads scale, but their data can be slightly out of date.**

A replica copies changes from the primary a fraction of a second later. If a
user creates a note and their next GET goes to a replica that hasn't caught
up, the new note is missing from their list for a moment, which looks like a
bug.

- **What we gain:** reads are spread over several machines, and the primary
  only handles writes.
- **What we give up:** "read your own write straight away" is no longer
  guaranteed.
- **How we limit it:** for a few seconds after a user writes, read that
  user's notes from the primary, or have the app return the new note in the
  POST response so the page can add it without reading it back.

Other trade-offs you could use instead:

- **Cache:** faster reads, but data can be out of date if we forget to delete
  the cached copy, and it's one more system to run.
- **Queue:** fast responses, but the email or export happens a little later,
  and failed jobs need retrying.
- **Cost and complexity:** about 10 components instead of 1. More things to
  pay for, monitor and debug.

## 3-minute presentation outline

| Time | Who | What to say |
|---|---|---|
| 0:00–0:30 | Speaker 1 | Stage 1: one server. Name its two problems: single point of failure, can't grow past one machine. |
| 0:30–1:30 | Speaker 2 | Walk through the components in order. One sentence each on the problem it solves. |
| 1:30–2:15 | Speaker 3 | Trace the three coloured paths on the diagram: page load, GET, POST. Point out that reads, writes and slow jobs each go to a different component. |
| 2:15–3:00 | Speaker 4 | Load estimate (reads ≈ 10× writes) and the replica trade-off. |

With 3 people, Speaker 1 also presents the load estimate.
