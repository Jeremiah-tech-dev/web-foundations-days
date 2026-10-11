# SnapShare Scaling Plan

SnapShare is a photo-sharing app. Users upload photos and scroll a feed of
photos from the people they follow.

## 1. Assumptions

**Given:**

- 10,000,000 registered users
- 10% of users are active each day
- Each active user uploads **1 photo** per day
- Each active user views **50 feed pages** per day
- An average photo is **2 MB**, and each photo also gets a **50 KB thumbnail**
- Peak traffic is **5×** the average

**Our own assumptions:**

- A day has 86,400 seconds, and traffic is counted as if spread evenly before
  applying the peak factor.
- A feed page shows **10 photos**, as thumbnails. The full photo loads only
  when a user opens it.
- Storage uses 1 MB = 1,000 KB, 1 GB = 1,000 MB and 1 TB = 1,000 GB.
- Each photo's details (owner, caption, time, file locations) take about
  **1 KB** in the database.
- Photos are kept forever, and the numbers don't include backup copies.

## 2. Estimates

### Daily active users

10,000,000 × 10% = **1,000,000 daily active users**

### Uploads per second

| | Calculation | Result |
|---|---|---|
| Uploads per day | 1,000,000 × 1 | 1,000,000 |
| Average | 1,000,000 ÷ 86,400 | **≈ 12 uploads/s** |
| Peak | 12 × 5 | **≈ 58 uploads/s** |

### Feed views per second

| | Calculation | Result |
|---|---|---|
| Feed pages per day | 1,000,000 × 50 | 50,000,000 |
| Average | 50,000,000 ÷ 86,400 | **≈ 579 feed views/s** |
| Peak | 579 × 5 | **≈ 2,894 feed views/s** |

Each feed page shows 10 thumbnails, so that is about **5,800 image
requests/s** on average and **~29,000/s** at peak. That adds up to about
**25 TB of thumbnails served per day**.

### Storage per year

| | Per day | Per year (× 365) |
|---|---|---|
| Original photos (1,000,000 × 2 MB) | 2 TB | **730 TB** |
| Thumbnails (1,000,000 × 50 KB) | 50 GB | **18.25 TB** |
| **Total photo files** | **2.05 TB** | **≈ 748 TB** |
| Photo details in the database (1,000,000 × 1 KB) | 1 GB | ≈ 365 GB |

The photo files are about 2,000 times larger than the database rows that
describe them.

## 3. Read-heavy or write-heavy?

SnapShare is **read-heavy**. Each active user makes 1 upload but views 50 feed
pages a day, so there are **50 reads for every write**. Counting each
thumbnail on a feed page, it's closer to **500 image reads for every upload**.

**What that means for the design:**

- Most of the work is serving the same photos and feeds again and again. So
  the main job is making reads cheap: a **CDN** for the image files, a
  **cache** for feeds, and **read replicas** for database reads.
- Writes are rare, about 58 per second at peak. One **primary database** can
  handle them, so we don't need to split the database across several primary
  servers yet.
- The slow part of a write, creating the thumbnail, can be moved off the
  request into a **queue** without users noticing.

## 4. Why photos don't go in the database

Photos should **not** be stored inside the database:

- **Size:** about 750 TB a year of files would make the database huge. It
  would also be slow to back up, restore and copy to replicas.
- **Cost:** database storage runs on fast, expensive disks built for small rows
  and queries, not large files that are written once and never changed.
- **Load:** every image request would become a database query. That's
  ~29,000 per second at peak, competing with the feed queries the database
  actually needs to answer.
- **Delivery:** the database can't hand files to a CDN or to the browser
  directly, so every image would have to pass through an app server.

**Instead, photos go in object storage** (for example Amazon S3, Google Cloud
Storage or Cloudflare R2). It is cheap, stores files reliably across several
machines, grows without limit, and serves files over HTTP, so a CDN can sit in
front of it. The database stores only each photo's **details and file
location**, for example `photos/8f3a.jpg` and `thumbs/8f3a.jpg`.

## 5. Architecture

```
                          ┌──────────────┐
            ┌────────────>│     DNS      │  snapshare.com → IP addresses
            │             └──────────────┘
   ┌────────┴────────┐  photos, thumbnails, ┌──────────────────────┐
   │ Users / clients │  HTML/CSS/JS         │         CDN          │
   │ (web, mobile)   │ ───────────────────> │ (copies near users)  │
   └────────┬────────┘                      └──────────┬───────────┘
            │ API calls (HTTPS, JSON)                  │ on a miss, fetch
            v                                          │ the file once
   ┌─────────────────┐                                 v
   │  Load balancer  │                      ┌──────────────────────┐
   └────────┬────────┘                      │    Object storage    │
      ┌─────┴──────┬────────────┐           │ originals/ thumbs/   │
      v            v            v           └──────────────────────┘
  ┌───────┐    ┌───────┐    ┌───────┐     save original ^     ^ save
  │ App 1 │    │ App 2 │    │ App 3 │ ──────────────────┘     │ thumbnail
  └───┬───┘    └───┬───┘    └───┬───┘                         │
      │            │            │       ┌───────────────┐     │
      │            │            ├─────> │ Cache (Redis) │     │
      │            │            │       │ feeds, users  │     │
      │            │            │       └───────────────┘     │
      │ writes     │ reads      │ jobs                        │
      v            v            v                             │
 ┌─────────┐ copy ┌──────────┐ ┌───────┐    ┌─────────────────┴─┐
 │ Primary │─────>│   Read   │ │ Queue │───>│ Thumbnail worker  │
 │   DB    │      │ replica  │ └───────┘    │ (1 or more)       │
 └─────────┘      └──────────┘              └─────────┬─────────┘
      ^                                               │
      └────────────── mark photo "ready" ─────────────┘
```

All three app servers are identical and connect to the cache, the databases,
the queue and object storage. The diagram draws one arrow of each kind to keep
it readable.

## 6. Components

| Component | Problem it solves |
|---|---|
| **DNS** | Turns `snapshare.com` into server addresses, so users never need IPs and we can change servers behind the name. |
| **CDN** | Serves photos, thumbnails and the front-end files from locations close to each user. That avoids sending ~25 TB a day of images from our own servers, and pages load faster. |
| **Load balancer** | Spreads API requests across the app servers and stops sending traffic to any server that fails, so no single server can take the app down. |
| **App servers (stateless)** | Run the API (log in, upload, get feed). Because they keep no user data in memory, we can add more at peak and any server can handle any request. |
| **Cache (Redis)** | Keeps each user's recent feed and popular profiles in memory. That way most of the ~2,900 feed views per second at peak never reach the database. |
| **Primary database** | Is the single trusted place where all writes go (new photos, follows, likes), so the data stays consistent. |
| **Read replica** | Is a copy of the primary that answers read queries the cache misses, so reads don't slow down writes. |
| **Object storage** | Stores the ~750 TB a year of photo files cheaply and reliably, outside the database. |
| **Queue** | Holds "make a thumbnail" jobs, so the upload request can return straight away. Jobs aren't lost if a worker is busy or crashes. |
| **Thumbnail worker** | Takes jobs from the queue, creates the 50 KB thumbnail and saves it, in the background. More workers can be added if the queue gets long. |

## 7. Upload flow

1. **Choose a photo.** The user picks a photo in the app, which sends
   `POST /photos` over HTTPS with the image file and a caption.
2. **Load balancer.** It forwards the request to any healthy app server.
3. **Check the request.** The app server checks that the user is logged in,
   that the file is an image, and that it is no bigger than the size limit.
   If any check fails, it returns `400` or `401`.
4. **Save the original.** The app saves the file in **object storage**
   under a new unique name, for example `originals/8f3a.jpg`.
5. **Save the details.** The app inserts a row into the **primary database**
   with the owner, caption, upload time and file location, and with
   `status = 'processing'`. The database gives the photo an `id`.
6. **Add a job.** The app adds a job to the **queue**: "make a thumbnail for
   photo 8f3a".
7. **Reply to the user.** The app returns `201 Created` with the new photo's
   `id`. The user sees "Uploaded" straight away and doesn't wait for the
   thumbnail.
8. **Worker picks up the job.** A thumbnail worker takes the job from the
   queue and downloads `originals/8f3a.jpg` from object storage.
9. **Make the thumbnail.** The worker shrinks the photo to a 50 KB thumbnail
   and saves it as `thumbs/8f3a.jpg` in **object storage**.
10. **Mark it ready.** The worker updates the photo's row in the **primary
    database**: it adds the thumbnail location and sets `status = 'ready'`.
    Then it marks the job as done.
11. **Clear old feeds.** The worker deletes the cached feeds of the user's
    followers (or they expire on their own soon after), so the new photo
    appears the next time each follower loads their feed.
12. **Show it.** When a follower scrolls their feed, the app returns the
    photo's details. The follower's browser loads the thumbnail from the
    **CDN**. The first request copies it from object storage, and later
    requests are served by the CDN directly.

**If the worker fails:** the job stays in the queue and is retried. After a
few failures it goes to a separate list of failed jobs for someone to look at.
Until then, the photo is `processing` and doesn't appear in feeds yet.

## 8. Trade-offs

### 1. Creating thumbnails in the background: fast uploads, but a short delay

- **Gain:** uploads return in well under a second, even when 58 arrive per
  second. A slow or failed thumbnail job doesn't break the upload, because the
  queue retries it.
- **Cost:** a new photo is `processing` for a few seconds before it appears in
  followers' feeds. We also have a queue and workers to run and monitor.
- **Why it's worth it:** users care more about a fast upload than about a
  photo appearing in other people's feeds that very second.

### 2. Cache and read replica: fast feeds, but sometimes slightly out of date

- **Gain:** most feed views come from memory, and the rest go to a replica.
  The primary database only handles writes.
- **Cost:** a cached feed can be a little old, and a replica copies changes a
  moment after the primary. So a follower might not see a new photo, or a
  user's own new photo, for a short time.
- **How we limit it:** keep cached feeds for a short time only (for example
  60 seconds), and clear them when someone a user follows uploads. Show the
  uploader their own photo from the upload response instead of reading it
  back from a replica.

### 3. Object storage and CDN: cheap and fast, but we pay for traffic and old copies can linger

- **Gain:** storing about 750 TB a year costs far less than database disks,
  and the CDN takes nearly all image traffic off our servers.
- **Cost:** CDN providers charge for every gigabyte they serve, and we serve
  about 25 TB a day. If a user deletes a photo, copies already on the CDN can
  stay available until they expire unless we explicitly purge them.
- **How we limit it:** feeds show the 50 KB thumbnails, not the 2 MB
  originals, which cuts the data sent per feed page about 40 times. Deleting a
  photo also sends a purge request to the CDN.
