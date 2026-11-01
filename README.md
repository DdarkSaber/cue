# Cue

**Your next story, one swipe at a time.**

Cue is a free, private recommender for **anime, manga, manhwa, manhua, K/C/J-dramas, series and movies**. Open it, see one poster, swipe. It learns what you are in the mood for and keeps your history on your own device.

No accounts, no ads, no analytics, no trackers.

| | |
|---|---|
| **Web app** | https://cue-next.cue-worker.workers.dev |
| **Android** | build the APK (see [Run it yourself](#run-it-yourself)) |

---

## Contents

- [What it does](#what-it-does)
- [Live mood](#live-mood)
- [Privacy](#privacy)
- [How it works](#how-it-works)
- [Run it yourself](#run-it-yourself)
- [Deploy your own copy](#deploy-your-own-copy)
- [Project layout](#project-layout)
- [Status](#status)

---

## What it does

- **Swipe deck.** Right = *Will try*, left = *Not interested*, up = *Watched / Read it*, down = *Not now* (hidden for 14 days). Remap any direction in Settings. Buttons, arrow keys and screen readers work too, and Undo always works.
- **Honest reasons.** Every card says why it is there ("because you rated X highly"). No fake match percentages.
- **Bring your history.** Upload a MyAnimeList XML, Netflix viewing activity, a Mihon/Tachiyomi backup, any CSV or Excel sheet with a Title column, or a Cue backup. Or sign in to MyAnimeList, or type a public AniList username. Everything is previewed first and every import can be undone.
- **Imports survive closing the app.** Matching resumes from a local checkpoint for the active library. Ready previews and your inclusion choices stay on this device until you confirm or cancel; they are never automatically imported or synced. Interrupted catalog requests may be repeated, but completed matching chunks are kept.
- **One combined history per library.** Excel and MAL imports merge into the selected library using matched catalog identities, preserving stronger statuses and your manual edits. Different local libraries stay separate; unmatched or uncertain rows still need review before they become known history.
- **New means new.** Suggestions exclude all titles already saved in the selected library, including watching, reading and planned titles. The old default-rewatch preference no longer brings history into ordinary suggestions. Choose **Revisit** explicitly for titles rated Rewatched / Would rewatch, or with an actual watch date more than three years ago.
- **Browse each local library.** In Settings > This library, tap a library to see its titles grouped by media type and sorted by name. Search or filter by anime, movies, dramas and reading types; remove incorrect titles with confirmation. Browsing does not switch libraries: use **Use this library** to switch. You can delete any local library independently; deleting the last one creates a fresh empty library.
- **One title, many names.** Manhwa and manhua often have 3 or 4 names. Cue checks official, romanised and fan names (AniList, MangaDex, MangaUpdates) and asks you before linking anything it is unsure of.
- **Sync between phone and web** with a code, end-to-end encrypted. Optional.

## Live mood

Cue works out what you feel like **right now**, on your device:

- It learns your **modes** from what you pick (for example "Isekai · Fantasy" or "Romance · Comedy") and notices within a few swipes when you switch.
- It learns what **your words** mean ("grind", "slow", "trash") from what you choose after typing them. Recognised format and genre keywords work immediately; other word meanings are learned from your picks.
- A **"Cue read: …"** chip shows its guess. Tap to correct it, long-press to rename a mood.
- Recognised format and positive genre words set strict filters: "fast paced comedy kdrama" requires K-drama and Comedy, not Action. The filter sheet also exposes required genres. Mood and pacing remain soft preferences because catalog pace metadata is incomplete; no instant pace guarantee or AI subscription is required.
- Optional **Smarter mood text** (off by default) sends only the sentence you type to an AI service (Groq, falling back to Google Gemini) for genre hints.

Clear everything any time in *Settings > Privacy*.

## Privacy

- Your library lives on your device (SQLite). Nothing is uploaded unless you turn on sync.
- Sync encrypts the library on the device (AES-256-GCM, keys derived from your 32-character code). The server stores only ciphertext and cannot read it.
- Catalog lookups send title names or catalog ids, never your history.
- Sign-in uses the provider's own page. Cue never sees a password. Tokens stay on the device.
- Pending imports keep parsed records (and uploaded bytes for date correction and duplicate detection) only in the local database. Confirming or cancelling removes that temporary payload; backups and sync contain no pending imports.
- Title removals use encrypted sync tombstones so an older device cannot silently add them back. An explicit later edit or confirmed re-import can restore a title. Deleting an entire local library forgets its local sync code but does not delete the server's encrypted copy or another device's library.
- No analytics, ads, trackers or remote fonts.

## How it works

```
 Flutter app (Android, web)                              Cloudflare Worker (free plan)
 +------------------------------+   HTTPS, fixed routes  +-------------------------------+
 | deck, ranker, live mood      | ---------------------> | /catalog  TVmaze, Cinemeta,   |
 | imports, library, sync       |                        |           MangaDex, MangaUpd. |
 | local SQLite (Drift)         |                        | /oauth    MAL token exchange  |
 +--------------+---------------+                        | /import   MAL list reads      |
                | HTTPS                                  | /sync     encrypted blobs (D1)|
                v                                        | /ai/mood  Groq / Gemini hints |
        graphql.anilist.co                               +-------------------------------+
   (anime and comics, called from the device,
    because AniList blocks Cloudflare)
```

| Data | Source | Key needed |
|---|---|---|
| Anime, manga, manhwa, manhua | AniList | no |
| K/C/J-dramas, series | TVmaze | no |
| Movies | Stremio Cinemeta (unofficial) | no |
| Comic alternate names | MangaDex, MangaUpdates | no |

**Tech:** Flutter, Riverpod, go_router, Drift · Cloudflare Workers, Hono, zod, KV, D1 · Vitest and flutter_test.

## Run it yourself

Needs Flutter (stable), Node 22+, and the Android SDK for phone builds.

```sh
# Worker
cd worker
npm ci
npm test && npm run typecheck
npx wrangler dev                    # local Worker on :8787

# App
cd app
flutter pub get
flutter analyze && flutter test
flutter run -d chrome --web-port 7357
flutter build apk --release         # APK in build/app/outputs/flutter-apk/
```

Release APKs are signed with the key named in `app/android/key.properties` (git-ignored). Without it they use the debug key.

**Install on Android:** copy the APK to the phone, open it, and allow installs from that app when asked.

## Deploy your own copy

Everything fits the Cloudflare free plan.

```sh
cd worker
npx wrangler d1 migrations apply cue-sync --remote
npx wrangler deploy

cd ../app
tool/build_web.sh https://<your-worker>.workers.dev
npx --prefix ../worker wrangler deploy
```

Update the KV and D1 ids and `ALLOWED_ORIGINS` in `worker/wrangler.toml` for your account.

### Optional keys

All free. Set secrets from `worker/` with `npx wrangler secret put NAME`. Never put them in the app or in git.

| Name | Turns on | Get it at |
|---|---|---|
| `MAL_CLIENT_ID` (var) + `MAL_CLIENT_SECRET` | MyAnimeList sign-in and username import | myanimelist.net/apiconfig |
| `GROQ_API_KEY` | Smarter mood text | console.groq.com |
| `GEMINI_API_KEY` | Smarter mood text fallback | aistudio.google.com |
| `TMDB_API_KEY` | Richer dramas, series and movies (optional) | themoviedb.org |

For MyAnimeList, register both redirect URLs: `https://<your-site>/auth.html` and `cue://oauth/mal`.

Check how well a list file matches the live catalogs (the file is read from the path you give and never stored):

```sh
cd app
CUE_LIVE_FILE=path/to/your-list.xlsx flutter test test/live/import_check_test.dart
```

## Project layout

```
app/                Flutter app
  lib/app/          theme, routing, providers
  lib/features/     screens: deck, library, imports, settings, sync
  lib/domain/       ranker, live mood (lib/domain/mood), models
  lib/data/         local database, catalog, repositories
  lib/imports/      file detection, adapters, title matching
  lib/sync/         end-to-end encrypted sync
worker/             Cloudflare Worker
  src/catalog/      TVmaze, Cinemeta, MangaDex, MangaUpdates, cache
  src/imports/      MAL lists and token exchange
  src/sync/         encrypted blob store (D1)
  src/ai/           mood hints (Groq, Gemini)
fixtures/           synthetic test files only
```

## Status

Working: deck, ranker, live mood, imports with undo, MyAnimeList sign-in with renewal, AniList by username, library, encrypted sync (titles, lists, settings, mood), Android and web.

Not planned for now: iOS, Trakt, MyDramaList and Prime Video sign-in (their data can still come in as a CSV).

Contributions: keep test fixtures synthetic. Never commit a real export.
