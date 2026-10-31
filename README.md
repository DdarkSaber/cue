# Cue

A swipe-card recommender for anime, K/C/J-dramas, series, movies, manhwa, manhua and manga. Open it, see one poster, decide with a swipe. Personal history stays on the device.

Free and non-commercial. No accounts, ads, analytics or trackers.

- Web app: https://cue-next.cue-worker.workers.dev
- Android: `app/build/app/outputs/flutter-apk/app-release.apk` after `flutter build apk --release`

## How it works

```
Flutter app (Android, web; iOS later)                Cloudflare Worker (TypeScript)
  deck, gestures, ranker, imports, sync    HTTPS       fixed endpoints only
  local database (Drift / SQLite)       ----------->   /catalog/*  TVmaze, Cinemeta (+ KV cache)
  AniList queries (fixed, public)                      /oauth/*    token exchange
       |                                               /import/*   MAL, Trakt list reads
       v HTTPS                                         /sync/*     encrypted blobs (D1)
  graphql.anilist.co
```

- **Swipes.** Default: right = Will try, down = Not now (hidden 14 days), up = Watched / Read it (seen, not "completed"), left = Not interested (until restored). Settings > Swipe actions lets you remap any direction. Buttons, arrow keys and screen-reader actions do the same thing, and Undo always works, even after a restart.
- **Recommendations are rules, not a model.** The ranker runs on the device: hard filters (hidden, deferred, saved, seen titles and the filter sheet), then a score from tags you rated well, the mood you picked, catalog quality, freshness and a little exploration. A small in-session lean follows what you keep or skip right now (never stored). Each card gets one true reason line, never a fake match percentage.
- **Moods are tag sets.** Hype, Comfort, Gripping and Feels map to catalog tags. "Tell me what you feel like" is read on the device with keyword rules. AI parsing is not used.
- **Sources, none needing a key or an account.** AniList for anime, manga, manhwa and manhua; TVmaze for K/C/J-dramas and series; Stremio's public Cinemeta catalog for movies (an unofficial source). AniList refuses requests from Cloudflare Workers, allows browser origins and allows only about 30 calls a minute, so the app calls it directly with fixed queries and paces itself. Everything else goes through the Worker. A TMDB key, if you ever add one, takes over dramas, series and movies.
- **Imports are local.** Files (Excel .xlsx, MAL XML, Netflix CSV, Mihon backup, CSV, Cue backup) are detected by their bytes, parsed on the device, matched (catalog id first, then exact title, then a similar title you tick yourself, else a review queue), previewed, and committed in one batch you can undo. Sign-in sources use the provider's own page with PKCE, read once, keep no login. AniList lists also work by public username.
- **Sync is optional and end-to-end encrypted.** A 32-character code encrypts the library on the device (AES-256-GCM, keys from HKDF). The Worker stores only ciphertext and a hash of the write token.
- **Posters** come from AniList, TVmaze or Cinemeta (and TMDB if keyed).

## Keys (all optional, all free)

Never in the app. Set them on the Worker from `worker/` with `npx wrangler secret put NAME`.

| Secret | Turns on | Register at |
|---|---|---|
| `TMDB_API_KEY` | Optional. Richer data and where-to-watch; dramas, series and movies work without it | themoviedb.org > Settings > API (needs personal details) |
| `MAL_CLIENT_ID` (+ `MAL_CLIENT_SECRET` for "web" apps) | MyAnimeList sign-in and username import | myanimelist.net/apiconfig |
| `ANILIST_CLIENT_ID`, `ANILIST_CLIENT_SECRET` | AniList sign-in (username import needs nothing) | anilist.co/settings/developer |
| `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET` | Trakt sign-in | trakt.tv/oauth/applications |

Redirect URIs to register: `cue://oauth/<provider>` (Android) and `https://cue-next.cue-worker.workers.dev/auth.html` (web). Without a key, that source shows as "not set up" and the rest keeps working.

## Run it

Requirements: Flutter (stable), Android SDK with an emulator, Node 22+.

```sh
# Worker
cd worker
npm ci
npm test && npm run typecheck
npx wrangler dev                          # local Worker on :8787

# App
cd app
flutter pub get
flutter analyze && flutter test
flutter run -d <emulator-id>              # debug build talks to 10.0.2.2:8787
tool/build_web.sh http://127.0.0.1:8787   # web build for the local Worker
```

## Check an import file against the live catalogs

```sh
cd app
CUE_LIVE_FILE=path/to/your-list.xlsx flutter test test/live/import_check_test.dart
```

Prints match rates per kind (exact, similar, none, not checked) and lists the misses. The file is read from the path you give and never stored in the repo.

## Deploy (Cloudflare free plan)

```sh
cd worker && npx wrangler d1 migrations apply cue-sync --remote && npx wrangler deploy
cd app && tool/build_web.sh https://cue-worker.cue-worker.workers.dev && npx --prefix ../worker wrangler deploy
```

Release Android builds sign with the key named in `app/android/key.properties` (gitignored; the keystore lives outside the repo). Without it they fall back to the debug key.

## Repository layout

```
app/        Flutter app (lib/app, lib/features, lib/domain, lib/data, lib/imports, lib/sync)
worker/     Cloudflare Worker (Hono, zod, Vitest, D1 migrations)
```

## Privacy and security rules

- No analytics, ads, trackers or remote fonts. DM Sans is bundled.
- Personal data is never committed or bundled. `.gitignore` blocks common export filenames.
- No password field for any third-party service; sign-ins use the provider's page.
- The Worker exposes fixed endpoints only: no URL pass-through, image host allowlist, per-IP rate limits, 8 KB request cap (2 MB for encrypted sync), logs without bodies, query strings or tokens.
- Android backups are disabled so the local library never leaves the device that way.

## Milestones

| | Milestone | State |
|---|---|---|
| M0 | Scaffold: app shell, theme, Worker skeleton, CI | done |
| M1 | Catalog: discover, title, search, KV cache, local catalog, posters, offline | done |
| M2 | Deck: card, gesture engine, four actions, keys, toast, undo, decisions persisted | done |
| M3 | Ranker, mood rail, filter sheet, reasons, details sheet, desktop split card | done |
| M4 | Imports: upload any file, preview, commit, undo import | done |
| M5 | Library, Will try, Settings (swipe remap, export, delete, motion, privacy) | done |
| M6 | Sign-in imports (MAL, AniList, Trakt), Mihon adapter | done (keys needed for sign-in) |
| M7 | Icon, release signing, reading badges, polish | done (AI mood parsing left off on purpose) |
| M8 | End-to-end encrypted sync between devices | done |
| Later | Live mood analyser, iOS, MyDramaList, Prime Video, removals that sync | |
