# Cue

A swipe-card recommender for anime, K/C/J-dramas, series, manhwa, manhua and manga. Open it, see one poster, decide with a swipe. Personal history stays on the device.

> Status: **M0 (scaffold) done.** The app shell, theme, navigation and Worker skeleton exist. There are no real cards yet: the catalog arrives in M1 and the swipe deck in M2. See [Milestones](#milestones).

## How it works

```
Flutter app (Android, web; iOS later)          Cloudflare Worker (TypeScript)
  deck, gestures, ranker, imports      HTTPS     fixed endpoints only
  local database (Drift / SQLite)   ---------->  /catalog/*  AniList, TMDB, TVmaze
  secure storage for OAuth tokens                /oauth/*    token exchange
                                                 /ai/mood    optional LLM
                                                 KV cache of public catalog data
```

- **Swipes.** Right = Will try (shortlist). Down = Not now (hidden 14 days). Up = Watched / Read it (seen, not "completed"). Left = Not interested (until restored). Buttons, arrow keys and screen-reader actions do the same thing, and Undo always works.
- **Recommendations are rules, not a model.** The ranker runs on the device: hard filters (exclusions, deferrals, seen titles, the filter sheet), then a score built from tag overlap with the titles you rated, the mood you picked, catalog quality, freshness and a little exploration. Each card gets one templated reason line that is true ("Hype like X, which you rewatched"), never a fake match percentage. Details: `docs/CUE-HANDOFF.md` section 7.2.
- **Moods are tag sets, not sentiment analysis.** Hype, Comfort, Gripping and Feels each map to a list of catalog tags (section 7.2). The "Tell me what you feel like" box is parsed on the device with keyword rules first. Only if those find nothing, and only if the person turns AI on in Settings, the sentence alone (max 200 characters, no history) goes to `/ai/mood`, which asks Gemini (then Groq) to turn it into filters. Without a key, everything still works on rules.
- **Imports are local.** Files (MAL XML, Netflix CSV, Mihon backup, CSV, Cue backup) are parsed on the device, previewed, then committed in one batch that can be undone. Sign-in sources (MAL, AniList, Trakt) use the provider's own page with PKCE and are read-only.
- **Posters** come only from AniList, TMDB or TVmaze, proxied through an allowlist.

## Where the API keys go

**Never in the app.** The app binary and web bundle contain no keys. All keys live in the Worker as Cloudflare secrets.

| Secret | Needed for | Milestone | Free? |
|---|---|---|---|
| none | AniList catalog (anime, manga, manhwa, manhua) | M1 | public API, no key |
| none | TVmaze fallback (series) | M1 | public API, no key |
| `TMDB_API_KEY` | Dramas and series from TMDB, where-to-watch | M1 | free key, attribution required |
| `MAL_CLIENT_ID` | MyAnimeList sign-in import | M6 | free app registration |
| `ANILIST_CLIENT_ID`, `ANILIST_CLIENT_SECRET` | AniList sign-in import | M6 | free app registration |
| `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET` | Trakt sign-in import | M6 | free app registration |
| `GEMINI_API_KEY`, `GROQ_API_KEY` | Optional "Tell me" AI parsing | M7 | free tiers |

Local development: copy `worker/.dev.vars.example` to `worker/.dev.vars` (gitignored) and fill in what you have. Deployed: `npx wrangler secret put TMDB_API_KEY` (and so on) from `worker/`. Until a key exists, the matching endpoint returns `501` and the app uses mocks behind the same interface.

## Run it

Requirements: Flutter (stable), Android SDK with an emulator, Chrome, Node 22+.

```sh
# App
cd app
flutter pub get
flutter run -d chrome --web-port 7357     # web
flutter run -d <emulator-id>              # Android
flutter analyze && flutter test

# Worker
cd worker
npm ci
npm test && npm run typecheck
npx wrangler dev                          # local Worker on :8787
```

## Repository layout

```
app/        Flutter app (lib/app, lib/features, lib/domain, lib/data, lib/imports)
worker/     Cloudflare Worker (Hono, zod, Vitest)
docs/       Product handoff, specs, design prototype, checklists
fixtures/   Synthetic sample files only
```

## Privacy and security rules

- No analytics, ads, trackers or remote fonts. DM Sans is bundled.
- Personal data is never committed or bundled. `.gitignore` blocks common export filenames.
- No password field for any third-party service; sign-ins use the provider's page.
- The Worker exposes fixed endpoints only: no URL pass-through, image host allowlist, per-IP rate limit, 8 KB request cap, logs without bodies or query strings.
- Android backups are disabled so the local library never leaves the device that way.

## Milestones

| | Milestone | State |
|---|---|---|
| M0 | Scaffold: app shell, theme, Worker skeleton, CI | done |
| M1 | Catalog: `/catalog/discover` and `/catalog/title`, KV cache, local catalog tables, image cache; real posters, offline after first run | next |
| M2 | Deck: card, gesture engine, four actions, keys, toast, undo, decisions persisted | |
| M3 | Ranker, mood rail, filter sheet, reasons, details sheet, desktop split card | |
| M4 | Imports: Upload any file, preview, commit, undo import | |
| M5 | Library, Will try, Settings (export, delete, motion, privacy) | |
| M6 | Sign-in imports (MAL, AniList, Trakt), Mihon adapter | |
| M7 | Optional AI mood parsing, reading badges, polish, Play Store internal release | |

Source of truth for decisions: `docs/CUE-HANDOFF.md`.
