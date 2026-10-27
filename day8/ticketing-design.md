# TicketHub Design

## 1. Requirements

**Functional:** browse and search events; view an event's seat map; hold up
to 4 seats for 10 minutes; pay for held seats; view my tickets.

**Non-functional**

- **Correctness:** a seat is never sold twice, and no one is charged without a ticket.
- **Fairness:** first come, first served through a waiting room, with a 4-ticket limit and rate limits against bots.
- **Speed:** pages load in under 1 s, and holding a seat answers in under 2 s, even during a big sale.
- **Availability:** 99.9%, and the site stays up when a popular concert goes on sale.
- **Security:** HTTPS everywhere. Card details go to a payment provider and are never stored.

## 2. Estimates

| | Normal day | Big sale (first 10 min) |
|---|---|---|
| Visitors | 50,000/day | 200,000 in 600 s |
| Requests | 500,000 page views/day = **6/s** (peak 5x = 29/s) | ~10 requests each = 2,000,000 = **3,300/s** |
| Tickets sold | 5,000/day = **0.06/s** | 20,000 seats = **33/s** |

The big sale is about **576x** normal traffic, compressed into 10 minutes, and
10 people want every seat. Normal days need only a small setup. The design must
survive a short, extreme spike in which most requests are reads (seat maps) and
the writes (holds) all compete for the same few rows. Order storage is tiny:
5,000 x 1 KB = ~2 GB a year.

## 3. API

| Method | Path | Purpose | Success |
|---|---|---|---|
| GET | /events?city=&date=&page= | Browse events | 200 |
| GET | /events/{id} | Event details | 200 |
| GET | /events/{id}/seats | Seat map with each seat's status | 200 |
| POST | /events/{id}/holds | Hold seats: `{"seatIds":[101,102]}` returns `holdId` and `expiresAt` | 201 |
| DELETE | /holds/{id} | Release a hold | 204 |
| POST | /orders | Pay: `{"holdId":"h_9","paymentToken":"tok_1"}` | 201 |
| GET | /me/tickets | My tickets with QR codes | 200 |

Errors: `409` seat already taken, `410` hold expired, `402` payment declined,
`429` too many requests or over 4 tickets, `401` not logged in.

## 4. Data model (PostgreSQL)

| Table | Columns |
|---|---|
| users | id PK, name, email UNIQUE, password_hash |
| events | id PK, name, venue, starts_at, sale_opens_at |
| seats | id PK, event_id FK, section, row, number, price, status (`available`/`held`/`sold`), held_by FK users, held_until; UNIQUE(event_id, section, row, number) |
| orders | id PK, user_id FK, total, status, payment_ref, created_at |
| tickets | id PK, order_id FK, seat_id FK **UNIQUE**, qr_code |

**Relationships:** users 1-to-many orders; events 1-to-many seats; orders
1-to-many tickets; each seat has **at most one** ticket (one-to-one).
Index: `seats(event_id, status)` for seat maps.

## 5. Preventing double-booking

1. **Atomic hold.** One transaction runs a conditional update:
   ```sql
   UPDATE seats SET status='held', held_by=$user, held_until=now()+interval '10 min'
   WHERE event_id=$e AND id IN ($seats)
     AND (status='available' OR (status='held' AND held_until < now()));
   ```
   If fewer rows changed than seats requested, it `ROLLBACK`s and returns
   `409`. The UPDATE **locks each row**, so when two people hit the same seat,
   the second waits, re-checks the WHERE, finds it `held`, and gets 0 rows.
2. **Safe payment.** `POST /orders` charges the card, then in one transaction
   locks the seats (`SELECT ... FOR UPDATE`), checks the hold is still the
   buyer's and not expired, inserts the order and tickets, and sets
   `status='sold'`. If anything fails, it all rolls back and the charge is
   refunded.
3. **Constraint as a safety net.** `UNIQUE(seat_id)` on tickets means that,
   even with a bug, the database refuses a second ticket for one seat.
4. Expired holds become `available` again, through the WHERE check and a worker.

## 6. Architecture

```
Users -> DNS -> CDN (pages, images, JS)
  |
  v
Waiting room (queue) -- lets buyers in at a safe rate, in arrival order
  |
  v
Load balancer -> App servers x N (stateless, autoscaled before a sale)
                   |-- Cache (Redis): seat maps (1 s), event pages, rate limits
                   |-- Primary DB: holds, orders, tickets (all writes)
                   |-- Read replicas: browsing, "my tickets"
                   |-- Payment provider (external)
                   +-- Queue -> Workers: email tickets, release expired holds
```

| Component | Problem it solves |
|---|---|
| CDN | Serves static files and event pages, so most of the 3,300 req/s never reach us. |
| Waiting room | Admits buyers at a rate the database can handle (e.g. 2,000 a minute), first come first served. That keeps the site up and fair. |
| Load balancer | Spreads traffic and skips failed servers. |
| App servers | Stateless, so we add more before a big sale. |
| Redis cache | Answers seat-map reads from memory and counts requests per user for rate limits. |
| Primary DB | One place for all seat writes, where transactions and locks make holds correct. |
| Read replicas | Take browsing reads off the primary. |
| Queue + workers | Send ticket emails and free expired holds in the background. |

**Surviving the big sale:** the CDN and waiting room absorb the crowd, the cache
serves 200,000 people's seat maps, and only holds and payments (a few hundred a
second) reach the primary database, which one PostgreSQL server can handle.

## 7. Trade-offs

1. **Waiting room: fairness and stability vs waiting.** Buyers may queue for
   minutes, but the site stays up and seats go in arrival order instead of to
   whoever refreshes fastest.
2. **Cached seat map: speed vs freshness.** The map can be 1 s old, so a user
   may click a seat that was just taken. They get a `409` and pick another.
   Correctness comes from the database, not the cache.
3. **One primary for seats: correctness vs scale.** Simple and strongly
   consistent. A few hundred writes a second fit one server. If we outgrow it,
   we can split events across databases.
4. **10-minute holds: fair checkout vs unsold time.** A seat waits while
   someone pays, but no one loses a seat while typing their card details.
