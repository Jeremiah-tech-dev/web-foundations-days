# SnapShare Scaling Plan

## 1. Assumptions

- 10,000,000 registered users, 10% active each day = **1,000,000 daily active users**.
- Each active user uploads 1 photo and views 50 feed pages per day.
- A photo is 2 MB, and its thumbnail is 50 KB.
- Peak traffic is 5 times the average.
- A day is 86,400 seconds, and 1 TB = 1,000,000 MB.
- Photos are kept forever, and backups are not counted.

## 2. Estimates

| | Per day | Average | Peak (5×) |
|---|---|---|---|
| Uploads | 1,000,000 | ≈ 12/s | ≈ 58/s |
| Feed views | 50,000,000 | ≈ 579/s | ≈ 2,894/s |

**Storage:** 1,000,000 photos × (2 MB + 0.05 MB) = 2.05 TB per day.
× 365 = **≈ 748 TB per year** (730 TB of photos + 18 TB of thumbnails).
Photo details in the database, at about 1 KB per photo, add only ~365 GB a year.

## 3. Read-heavy or write-heavy?

**Read-heavy:** there are 50 feed views for every upload. So the design makes
reads cheap, with a CDN for images, a cache for feeds and a read replica for
database reads. Writes peak at only ~58/s, which one primary database can
handle. The slow part of an upload, making the thumbnail, moves to a
background queue.

## 4. Where do the photos go?

**Not in the database.** About 750 TB a year of large files would make the
database huge, slow to back up and copy to replicas, and expensive. Every
image view would also become a database query, and a CDN can't fetch files
from a database. Photos go in **object storage** (for example Amazon S3),
which is cheap, reliable, practically unlimited and serves files over HTTP
with a CDN in front. The database stores only each photo's details: id,
owner, caption, upload time and file locations.

## 5. Architecture

```
Users (web / mobile app)
  |  photos, thumbnails, HTML/CSS/JS                on a miss
  +--------------------------------------> CDN ----------------+
  |  API calls (HTTPS, JSON)                                    |
  v                                                             v
Load balancer                                           Object storage
  |                                              (originals + thumbnails)
  +--> App server 1 --+                                ^           ^
  +--> App server 2 --+                                |           |
  +--> App server 3 --+-- save original ---------------+           |
                      |                                            |
                      +-- feeds ----> Cache (Redis)                |
                      |                                            |
                      +-- jobs -----> Queue --> Thumbnail worker --+
                      |                               |   save thumbnail
                      +-- writes ---> Primary DB <----+
                      |                   |      mark photo "ready"
                      |                   | copies changes
                      |                   v
                      +-- reads ----> Read replica
```

## 6. Components

- **CDN:** serves photos, thumbnails and front-end files from servers near
  users, so images load fast and most image requests never reach our servers.
- **Load balancer:** spreads API requests across the app servers and skips any
  that fail, so one crash doesn't take SnapShare down.
- **App servers (stateless):** handle API requests, and because they store no
  user data themselves, we can add more at peak times.
- **Cache (Redis):** keeps each user's prepared feed in memory, so most of the
  ~2,900 feed views per second at peak skip the database.
- **Primary database:** the single trusted place where all writes go (users,
  follows, photo details), which keeps the data consistent.
- **Read replica:** a copy of the primary that answers feed queries the cache
  misses, so reads don't slow down writes.
- **Object storage:** stores ~750 TB a year of photo files cheaply and
  reliably, outside the database.
- **Queue:** holds "make a thumbnail" jobs, so uploads return straight away
  and no job is lost if a worker is busy or crashes.
- **Thumbnail worker:** takes jobs from the queue and creates thumbnails in the
  background, and we add more workers if the queue grows.

## 7. Upload flow

1. The app sends `POST /photos` with the photo and caption. The load balancer
   forwards it to any app server.
2. The app server checks the user's login token and the file's type and size.
   If a check fails, it returns `400` or `401`.
3. It saves the original file to **object storage**, for example
   `originals/123.jpg`.
4. It inserts the photo's details into the **primary database** with
   `status = 'processing'`.
5. It adds the job "make thumbnail for photo 123" to the **queue**.
6. It replies `201 Created` straight away. The user doesn't wait for the
   thumbnail.
7. A **thumbnail worker** takes the job, downloads the original, and saves a
   50 KB thumbnail to object storage as `thumbs/123.jpg`.
8. The worker updates the photo's row with the thumbnail location and sets
   `status = 'ready'`. If the job fails, the queue retries it.
9. The followers' cached feeds are cleared, so the new photo appears the next
   time they scroll. Their browsers load it from the **CDN**.

## 8. Trade-offs

1. **Fast uploads vs a short delay.** Making thumbnails in the background keeps
   uploads fast even at peak. The cost is that the photo shows as
   "processing", or with a placeholder, for a few seconds before it appears in
   followers' feeds.
2. **Speed vs fresh data.** Feeds come from the cache and the read replica, so
   they are fast and the primary database stays free for writes. The cost is
   that a new photo may take a few seconds to appear for followers. That is
   acceptable for a social app, and we limit it by clearing feeds when someone
   uploads.
3. **Cost vs simplicity.** The CDN and object storage charge per gigabyte. Even
   so, they are far cheaper and more reliable than storing and serving
   hundreds of terabytes from our own servers. Feeds show 50 KB thumbnails
   instead of 2 MB originals to keep that cost down.
