# Testing and known limitations

[Back to Cue](../README.md)

## Regression scenarios

Suites use synthetic libraries, isolated databases and injected provider/AI
failures. They exercise real widgets, repositories and gesture recognizers;
platform suites run those flows on Android and Chrome. These are production-like
checks, not a guarantee of finding every corner case.

| Requirement | Coverage |
|---|---|
| Durable imports and review | Persistent SQLite reopen, chunk checkpoints, cancellation/retry/storage failure, explicit preview commit, canonical deduplication, separate profiles |
| Taste versus temporary intent | Weak unrated evidence, rating precedence, gradual confidence, unknown metadata neutrality, session expiry without rating/sync writes |
| Retrieval and constraints | Mixed-media seeds, missing-kind refill, page/request budgets, exact cache expiry, hard filters/history exclusions, partial failure, exhaustion recovery |
| Ratings and saved picks | Optional answers/Skip/dismissal, overwrite confirmation, exact/stale-safe Undo, factual comparison, saved-only deck, Tonight priority |
| Four swipes and Try now | Single/double-tap/drag arbitration, original directions, reduced motion, keyboard/custom semantics, duplicate promotion, fractional-timestamp Undo |
| Removal and sync | Atomic priority tombstones on entry/shortlist removal/reset, stale remote rejection, ordinary re-add, conflict convergence, profile isolation |
| Technical diagnostics | OFF/default/no backfill, strict private-field rejection, server-issued sessions, expired-ID rejection, off/on rotation, durable expiry/clock rollback, queued writes, fail-closed persistence, caps/retries, exact export |
| Layout and lifecycle | Small phone/desktop, 200% text/scrolling, accessible labels/targets, route/profile changes, async SQLite readiness |

## Latest checks

At commit `b9496eb`, both [GitHub CI jobs passed](https://github.com/DdarkSaber/cue/actions/runs/41332251606).
Local formatter used the same Flutter 3.47.9 / Dart 3.13.7 as CI:
181 files required no further formatting, analyzer was clean, and **397 app
tests passed**. One opt-in real-file import test was intentionally skipped:
no personal export was supplied or uploaded.

The diagnostics remediation passed **186 Worker tests**, including 62
diagnostics cases, plus TypeScript typecheck. Updated diagnostics/consent checks
passed **17/17 in actual debug Chrome**, **5/5 on the owned Android emulator**,
and a separate actual Android-client/local-D1 API roundtrip.

These include old-code/new-ID rejection, off/on isolation, serialized expiry
restore, authoritative server expiry with a wrong device clock, queued
persistence and late-response guards. The browser Settings fixture opens its
synthetic SQLite connection before mounting, and candidate assertions wait for
bounded deck readiness. Final platform builds are serialized because Flutter
regenerates shared plugin registrants.

Both production artifacts were rebuilt after remediation. The APK was installed
and cold-launched on the owned emulator; its Android Debug certificate was
verified. This is debug-signing fallback, not release credentials.

After the authorized Worker deployment on 2026-11-01, **18 live synthetic API
checks passed**: readiness, sync create/read/update/conflict/auth/delete, and
diagnostics create/export/schema rejection/dedup/expiry/session isolation.
Synthetic records were removed afterward. This was an API check, not another
two-device UI run.

## Earlier feature baseline

Before capability remediation: analyzer clean, **385 app tests**, three visually
reviewed phone/desktop goldens, **68 Android integrated scenarios**, an Android
diagnostics/local-D1 roundtrip, and **179 Worker tests** plus typecheck.
Golden changes were the selected synthetic title after ranking changes, not a
new home layout.

Actual Chrome debug integration passed **107/107**. Separate unchanged-CSP
release persistence/rating/details/session-data checks passed **67/67**.
A release deck group passed **7/7** after bounded test-only WASM-readiness
waits; a disposed-sync-reference defect was fixed and regression-tested.
These counts overlap app scenarios and must not be added as independent coverage.

The real production-web UI sent no AI request while OFF. A synthetic opt-in
sentence then returned HTTP 200 from Groq, with diagnostics OFF and no uploads.
This does not independently validate Gemini.

## Boundaries and residual risks

- Tests used an owned disposable emulator, never someone else's active emulator.
  Release launch and saved-priority process-stop/restart were checked separately
  from persistent import database reopen.
- An OS kill during import matching, real user databases, real OAuth/camera
  workflows, every browser/physical screen reader and every network outage were
  not validated.
- Flutter's release browser helpers have debug-only keyboard/semantics
  limitations. Those actions passed debug Chrome and Android; do not describe
  the entire release harness as green.
- The refreshed production preview rendered catalog cards on `localhost:7357`.
  An existing `127.0.0.1:7357` origin stalled while loading; its cause remains
  unresolved. No user data was cleared to work around it.
- Real Gemini key validity remains **unverified**; the user deferred that check.
- Security regression checks are not proof that no other leaks or bugs exist.

## Run checks

From `app/`:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

From `worker/`:

```sh
npm test
npm run typecheck
```

Optional live import check, from `app/` in a POSIX shell:

```sh
CUE_LIVE_FILE=path/to/your-list.xlsx flutter test test/live/import_check_test.dart
```

This explicitly selected file is read for matching and not stored as a fixture.
Do not commit real exports. See [Setup](SETUP.md) for platform commands.
