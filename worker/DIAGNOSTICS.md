# Optional technical cloud diagnostics

Diagnostics are **off by default in the client**. This endpoint does not enable
collection or create sessions by itself. The client must obtain separate,
explicit opt-in before sending technical events. It must not backfill history,
send diagnostics about diagnostics, or send anything while consent is off.
Turning consent off stops uploads; this API deliberately has no DELETE route.
No production migration, deletion, deployment, or cron change is part of this
implementation.

## Capability-authenticated API

The server generates a cryptographically random **32-byte** capability on
creation, encoded as canonical, unpadded base64url (43 characters). Clients
cannot choose a capability or session ID. Derive the session ID as lowercase
hex SHA-256 of the **UTF-8 encoded token string**, not the decoded random bytes.
Use HTTPS and keep the capability private on the device; do not put it in URLs,
analytics, logs, or diagnostic events. There is no shared server secret or
public diagnostics listing. Knowledge of an ID alone cannot authorize access.
The stored session ID is itself the capability digest; no raw token or additional
token hash is stored.

GET and PUT require `Authorization: Bearer <token>` and the matching
64-character ID. CORS/preflight is not authentication. Query parameters are
rejected.

- `POST /diagnostics`, `Content-Type: application/json`:
  `{"events":[...events]}` creates a session with **1–20** events.
  Success: HTTP 200 `{"token":"<server-issued-token>","accepted":N,"expiresAt":E}`.
  `E` is integer server epoch milliseconds, first accepted time plus seven days;
  `N` is integer 1–20 after deduplication. No ID is returned: derive it from
  the token string as above. **Any Authorization header** (even empty), query
  parameter, caller-chosen token/ID, or unknown field causes 400.
- `PUT /diagnostics/:id`, `Content-Type: application/json`:
  `{"events":[...events]}` appends **1–20** events atomically to an existing,
  unexpired session only. Success: HTTP 200 `{"accepted":N,"expiresAt":E}`,
  counting only newly accepted request IDs (`N` integer 0–20). `E` is the same
  fixed server expiry returned at creation. Missing or expired sessions return
  404; PUT **never creates or recreates** a session.
  All envelope and event fields are required as specified below; unknown fields
  are rejected, never silently stripped.
- `GET /diagnostics/:id`: HTTP 200 `{"events":[...events]}` with at most 100
  technical events in append order, or HTTP 404 `{"error":"not_found"}` for an
  absent/expired session. Server timestamps and other storage metadata are not
  returned. All diagnostics responses use `Cache-Control: no-store`.
- No DELETE, public listing, arbitrary metadata, or query-based token support.

Every event has exactly these fields:

| Field | Accepted values |
| --- | --- |
| `requestId` | Random UUID v4; canonical hyphenated format; case normalized to lowercase |
| `appVersion` | Numeric `major.minor.patch`, optionally `+build`, e.g. `0.1.0+1`; at most 32 characters; no prerelease labels |
| `provider` | `cue`, `anilist`, `mal`, `local` |
| `operation` | `discover`, `search`, `title`, `match`, `aliases`, `import`, `settings`, `mood` |
| `durationMs` | Integer 0–120000 |
| `status` | `ok`, `unavailable`, `rejected`, `failed` |
| `errorCode` | `none`, `network`, `http_4xx`, `http_5xx`, `rate_limited`, `not_configured`, `invalid_response`, `storage_failed` |

Never send titles, search queries, identifiers for media/users, URLs, arbitrary
strings, raw exception messages, client timestamps, tokens, names, account data,
files, or watch/import history. `requestId` must be newly random, not derived
from any personal data. Technical values must describe an operation, not encode
personal information in allowed numeric fields. Format validation cannot prove
that an untrusted client generated its UUID randomly or prevent covert
encoding; correct client UUID generation and minimization are essential.

For `POST /ai/mood`, use `provider:cue` and `operation:mood`. Instrument only
HTTP-header timing/status, never request/response bodies, phrase text, URLs,
AI provider keys, or raw errors. No Groq/Gemini provider names are added to the
diagnostics schema. The diagnostics upload client must remain uninstrumented
to avoid recursive collection.

## Limits, retention and errors

- Request body limit: **6 KiB**, including streamed bodies, stricter than the
  existing general 8 KiB cap.
- Existing Workers per-IP rate limiter remains in force (currently 120/minute).
  The IP is used transiently by that binding, never stored in diagnostics.
- One accepted new batch per session per **5 seconds**. A batch consisting only
  of already retained UUIDs is an idempotent success with `accepted:0`; it does
  not change timestamps or extend retention. Duplicate UUIDs within a batch
  are likewise counted once; the first accepted event wins.
- At most **100 events/session** and **1000 sessions globally**. Batches that
  would exceed the event cap are rejected whole; events are not evicted to make
  space. Updating an existing session does not consume another session slot.
- A session expires **exactly seven days after its first accepted batch**.
  Subsequent writes do not extend its lifetime. This intentionally bounds every
  event's retention to no more than seven days, even for continuously active
  devices. GET and PUT on expiry are 404, including duplicate-only PUT retries.
  An old capability cannot be used to upload new logs after expiry, physical
  pruning or deletion; there is no PUT creation fallback and no caller-chosen
  POST ID. A new POST receives a fresh server-generated capability. No
  tombstones or additional migration are needed.
- The client must start with POST lazily on its first consented batch, persist
  the returned server expiry with the capability, and abandon that capability
  on consent OFF, re-enable, expiry or 404. A new consent/session uses a new
  POST. Server capability expiry does not itself revoke read access before
  seven days: an old recovery code can still read its own historical session,
  but must never receive the new session's code or future events.
- POST is intentionally not idempotent and accepts no client creation token.
  A lost creation response can leave an unreachable session; retrying POST
  creates a separate session with a different token. Each orphan still counts
  toward the 1000 cap and expires within seven days, with the same bounded
  opportunistic cleanup. The client must not guess/reuse an old token to
  recover it. The raw capability is returned only by successful POST and is
  never stored or logged by the Worker.
- Server event receipt timestamps are stored only for retention. There are no
  client-supplied timestamps, token values, IPs, user agents, or device IDs in
  the table. GET returns only schema-validated technical fields.
- POST and authenticated GET/PUT opportunistically prune at most 25 expired sessions,
  plus the requested expired session. No background cron is added or changed.
  Expired records may remain physically stored when no traffic occurs, but
  are never returned; seven days is the logical retention window, not a promise
  of immediate physical erasure. Cleanup uses only the diagnostics table.
- Global capacity is enforced by a single conditional SQLite INSERT; updates
  use revision compare-and-swap and bounded retries, preventing lost events,
  global quota races, and per-session write-rate races.

Errors are fixed `{"error":"code"}` objects without submitted values or field
names:

| HTTP | Code | Meaning |
| --- | --- | --- |
| 400 | `invalid_request` | Bad JSON, wrong content type, unknown/missing/invalid fields, query parameters, or any Authorization header on POST |
| 403 | `forbidden` | Missing/malformed capability, invalid ID, or ID/token mismatch |
| 403 | `origin_not_allowed` | Existing browser origin middleware |
| 404 | `not_found` | Absent/expired session or unsupported route/method |
| 413 | `payload_too_large` | Body cap exceeded |
| 429 | `rate_limited` | Per-IP limit (`Retry-After: 60`) or session write/CAS contention (`Retry-After: 5`) |
| 429 | `quota_exceeded` | Session event cap, global session cap, or random creation collision fails closed (`Retry-After: 604800`, conservative backoff) |
| 503 | `unavailable` | Missing D1/rate-limit binding, unapplied migration, or storage read/write/cleanup failure |

Middleware can reject oversized, disallowed-origin or rate-limited requests
before route authentication. Normal request logs contain only method, matched
route **pattern**, status and duration; no capability, route ID, event, IP or
raw database errors are logged.

## Local setup and future deployment

Storage reuses `SYNC_DB` but only accesses `diagnostic_sessions`, defined by
`migrations/0002_diagnostics.sql` and its expiry index. Existing sync data and
its weekly cron are unchanged. No schema is silently created by a request.

Before running locally (and before any separately authorized future deployment),
apply the migration locally from `worker/`:

```powershell
npx.cmd wrangler d1 migrations apply SYNC_DB --local
npm.cmd test
npm.cmd run typecheck
```

The tests use the local Workers D1 binding, the actual migration and synthetic
random capabilities/events, never live provider data. Applying a remote
migration or deploying later requires separate authorization and review.

No telemetry SDK, external collector or paid service was added. These bounded
tables reduce abuse and storage growth, but route traffic, cleanup and CAS
retries still consume D1 reads/writes and Workers requests; diagnostics share
the same database/free-plan allowance with encrypted sync. Cloudflare free
plan quotas and terms can change, and exceeding them can make the feature
unavailable. This is not a free-forever or availability guarantee. The
1000-session cap is not a request-volume/billing cap; arbitrary attackers can
generate capabilities, so keep the existing perimeter rate limits and review
resource usage before enabling a future deployment.

Published free-plan limits checked on 2026-11-01:

| Resource | Free-plan limit |
| --- | --- |
| Workers requests | 100,000/day, account-wide |
| Workers CPU | 10 ms/request |
| D1 rows read | 5 million/day |
| D1 rows written | 100,000/day |
| D1 storage | 500 MB/database, 5 GB/account |
| D1 queries per Worker invocation | 50 |

D1 counts scanned rows and index maintenance, not just returned events. A
diagnostic session is one bounded JSON row; quota counts and pruning can still
scan other sessions. Exhausted free D1 allowances cause storage errors/503, not
silent acceptance. Platform request/CPU exhaustion may produce Cloudflare's
own errors before this route runs. The bounded five-attempt CAS loop stays
below the free invocation query limit.

Sources: [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/),
[D1 limits](https://developers.cloudflare.com/d1/platform/limits/), and
[Workers limits](https://developers.cloudflare.com/workers/platform/limits/).
Recheck these before future deployment; they are not contractual guarantees.
