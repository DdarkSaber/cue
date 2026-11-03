# Privacy and data lifecycle

[Back to Cue](../README.md)

## Library and imports

Your library lives in local SQLite. Library/history uploads require optional
encrypted sync. AI text, AI taste picks and technical diagnostics are separate opt-ins.
Catalog lookups send title names or IDs, never your whole history.
Provider sign-in uses the provider's page; Cue does not see passwords.
Tokens stay on the device.

Pending imports retain parsed records and uploaded bytes locally for date
correction and duplicate detection. Confirmation or cancellation removes that
temporary payload. Pending imports are excluded from backups and sync.

Title removals use encrypted sync tombstones so older devices cannot silently
restore them. A deliberate later edit or confirmed re-import can restore a title.
Deleting a local library forgets its local sync code, but does not delete the
server's encrypted copy or another device's library.

Sync uses AES-256-GCM with keys derived from your 32-character code.
The server stores ciphertext, not the decryption key. Keep the code safe:
if every device and code are lost, the copy cannot be recovered.
Local clearing controls are in Settings > Privacy.

## Device-only recommendation measures

Choice counts, explicit follow-up outcomes, exposure/repetition, format coverage
and detected constraint leaks are local proxies, not an accuracy score.
They are excluded from sync, backups and technical diagnostics, and can be
cleared independently. They do not prove full catalog coverage or enjoyment.
Temporary direction is described in [Recommendations](RECOMMENDATIONS.md).

## Optional technical diagnostics

Settings > Privacy explains consent before enabling. Collection is off by
default and has no retrospective disk backlog. Only random request IDs, numeric
app version, fixed provider/operation/status/error codes and bounded elapsed
time are allowed.

Never collected: titles, Tell me/search text, history, imported files, URLs,
tokens, keys, response bodies or raw errors. Turning off drops pending events
and stops collection/uploads. Failed preference writes are reported rather
than claiming durable success.

Recovery uses a server-issued random capability, not public logs or CORS as
authentication. No server secret is embedded in the app. Keep recovery codes
private; trusted troubleshooting can use authenticated export.

Limits are 20 events per upload, the first 100 unique events per session,
1,000 sessions globally and a fixed seven-day expiry from the server's first
accepted upload. Payload/rate/storage safeguards and explicit quota errors apply.
The app persists the server deadline; the server rejects expired/missing-session
writes even with a wrong device clock or old client.

Continuing after expiry, enabling again, or choosing Start new diagnostics
session creates a separate code on the next upload. Old codes cannot read future
sessions, but can read their own retained records until expiry. Turning off or
rotating cannot recall received uploads or immediately revoke old-record access.
Expired records are inaccessible; physical cleanup runs on later diagnostics
requests, not an exact deletion timer.

The matching Worker and `0002_diagnostics.sql` are required; they were deployed
on 2026-11-01. Self-hosted copies need their own migration/deployment.
Technical-only events cannot explain semantic title mismatches without title data.
See [Worker diagnostics](../worker/DIAGNOSTICS.md) for auth, retrieval and limits.

## Other network use

Optional Smarter mood text sends the typed sentence to an AI service for
allowlisted hints. It is not required for local mood rules.

Optional AI picks from my taste (Settings, off by default, offered once on the
deck when you have 5 or more liked titles) sends the Worker, and through it
Groq or Google Gemini, only: up to 25 liked titles (name, format, year and, for
explicit ratings, a 0-10 number), up to 10 disliked titles (name, format), your
enabled formats and no other library data. Ratings dates, notes, ids, sync
codes and import sources are never sent. The Worker does not log titles and
caches the answer for a few hours under a hash of the profile. Suggestions
are matched against the real catalog; unmatched, ambiguous, already-owned,
disliked, novel and music results are dropped. Turning it off stops all
requests; picks already stored stay on the device and are ignored.
There are no ads, trackers, third-party telemetry SDKs or remote fonts.
Provider and Cloudflare quotas can change; there is no paid-plan requirement
or guaranteed free-forever capacity.

Deleting live application rows does not erase Cloudflare-managed historical
backups or platform telemetry.
