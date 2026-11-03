<p align="center">
  <img src="docs/assets/hero.png" alt="Cue: your next anime, manhwa or K-drama, one card at a time" width="100%">
</p>

<p align="center">
  <a href="https://github.com/DdarkSaber/cue/actions/workflows/ci.yml"><img src="https://github.com/DdarkSaber/cue/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20Web-4c1d95" alt="Platforms: Android and Web">
  <img src="https://img.shields.io/badge/Flutter-3.47.9-02569B?logo=flutter&logoColor=white" alt="Flutter 3.47.9">
  <img src="https://img.shields.io/badge/backend-Cloudflare%20Workers-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare Workers">
</p>

<p align="center">
  <b>A free, private, poster-first swipe deck for anime, manga/manhwa/manhua,<br>
  K/C/J-dramas, series and movies.</b>
</p>

<p align="center">
  <a href="https://cue-next.cue-worker.workers.dev"><b>Open the web app</b></a> ·
  <a href="#android">Build the Android app</a> ·
  <a href="docs/FEATURES.md">Feature guide</a>
</p>

---

## Highlights

- **One card at a time.** Swipe right to save, left for Not interested, up for
  Watched / Read it, down for Not now. Buttons and keyboard work too.
  Double-tap to mark a saved pick as Try now; single-tap opens details.
- **Every format in one deck.** Anime, manga, manhwa and manhua, K/C/J-dramas,
  series and movies, mixed fairly across the formats you enable.
- **A deck that never dead-ends.** When exact matches run thin, a fallback
  ladder keeps cards coming with honest labels such as *Longer than requested*
  or *Outside your filter*. Your filter stays visible, and the deck opens
  instantly from cache.
- **Deep catalogs, not a first page.** Catalog paging goes deep, so anime does
  not run out after a few cards, and *Because you liked X* picks follow
  AniList's recommendation graph from titles you rated well.
- **Optional AI picks from your taste.** Turn it on and the Worker asks
  Groq (falling back to Gemini) for ideas. Every suggestion is resolved against
  the real catalog; nothing is fabricated, and unmatched ideas are dropped.
- **Bring your library.** Import supported files or lists, review matches, and
  confirm before saving. Interrupted matching resumes locally.
- **Explainable picks.** Filter formats and genres, describe your mood, or
  explore. Every card says why it was suggested.
- **Sync without an account.** Share an encrypted library between phone and
  web using a code.

## Screenshots

<p align="center">
  <img src="docs/assets/phone-showcase.svg" alt="Illustration of the Cue deck on a phone: an abstract poster card, a Because you liked reason chip and four swipe buttons" width="520">
</p>

<sub>An illustration with placeholder content; real cards show catalog
posters and the actual reason for each pick.</sub>

## How it works

Ranking, library evidence and mood run on your device. The Worker only serves
fixed catalog, sync and optional AI routes.

```mermaid
flowchart TD
  L[Library evidence<br/>ratings, imports, swipes] --> T[Taste profile<br/>weighted tags + interest clusters]
  T --> R{Retrieval}
  R --> R1[Deep catalog paging<br/>per enabled format]
  R --> R2[Because you liked X<br/>AniList recommendation graph]
  R --> R3[AI picks, opt-in<br/>resolved against the real catalog]
  R1 --> F[Hard filters<br/>formats, genres, length, history]
  R2 --> F
  R3 --> F
  F --> K[Local ranker<br/>taste, mood, quality, freshness]
  K --> M[Familiar / adjacent / explore mix]
  M --> X[Fallback ladder<br/>honestly labelled relaxations]
  X --> D[Poster deck]
  D -->|swipes and ratings| L
```

Evidence is counted once per title and never invented: imported history is a
weak signal, explicit ratings are strong. Hard filters and saved-history
exclusions apply before ranking. See [Recommendations](docs/RECOMMENDATIONS.md)
for weights, caps and the full fallback rules.

## Privacy

- **Your library lives on your device.** Optional sync uploads an encrypted
  copy (AES-256-GCM); the server never holds the key. Keep the code safe.
- **Catalog lookups** send title names or IDs, never your whole history.
- **AI is opt-in.** Smarter mood text sends only your typed sentence. AI picks
  send only the names of titles you liked, and only when you turn them on.
- **Diagnostics are off by default** and exclude titles, history, search text,
  files, tokens and raw errors.
- **No ads, trackers, third-party analytics SDKs or remote fonts.**

[Privacy and data lifecycle](docs/PRIVACY.md) ·
[Diagnostics setup and retrieval](worker/DIAGNOSTICS.md)

## Quick start

Use Flutter **3.47.9** (the CI version), Node **22+**, and the Android SDK for
phone builds. Run the Worker and app in separate terminals.

### Worker

```sh
cd worker
npm ci
npx wrangler d1 migrations apply cue-sync --local
npx wrangler dev
```

The Worker listens on port 8787. Optional keys go in gitignored
`worker/.dev.vars` (template: `worker/.dev.vars.example`).

### Web app

```sh
cd app
flutter pub get
flutter run -d chrome --web-port 7357
```

### Android

```sh
cd app
flutter pub get
flutter build apk --release
```

Install `app/build/app/outputs/flutter-apk/app-release.apk` on your phone.
Release signing uses `app/android/key.properties`; without it, the build uses
the **debug key**, not store-release credentials.

[Development, optional keys and deployment](docs/SETUP.md)

## Tech stack

| Layer | Technology |
|---|---|
| App | Flutter (Android, web), Riverpod, go_router |
| Local data | Drift (SQLite) |
| Backend | Cloudflare Workers, Hono, zod |
| Storage | Cloudflare KV (catalog cache), D1 (encrypted sync, diagnostics) |
| Catalogs | AniList, TVmaze, Stremio Cinemeta, MangaDex, MangaUpdates |
| Optional AI | Groq, with Gemini fallback, via the Worker |
| Tests | flutter_test (including golden images), Vitest |

## Project structure

```text
app/       Flutter UI, local database, ranking, imports and encrypted sync
worker/    Cloudflare API, catalog cache, sync storage and optional AI
fixtures/  Synthetic test data
docs/      Architecture, policies, setup, validation and README assets
```

## Documentation

| Guide | What's inside |
|---|---|
| [Features](docs/FEATURES.md) | Gestures, imports, filters, library and sync |
| [Recommendations](docs/RECOMMENDATIONS.md) | Evidence weights, ranking, retrieval and fallbacks |
| [Architecture](docs/ARCHITECTURE.md) | Components, data sources and flow diagram |
| [Setup](docs/SETUP.md) | Local development, provider keys and deployment |
| [Privacy](docs/PRIVACY.md) | What leaves the device, and when |
| [Testing](docs/TESTING.md) | Test results and known limitations |

## Contributing

Issues and pull requests are welcome. Before opening a PR, run the checks CI
runs (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)): `dart format`,
`flutter analyze` and `flutter test` in `app/`, and `npm test` plus
`npm run typecheck` in `worker/`.

Use synthetic fixtures only. Never commit a real library export, credentials
or provider keys.

Android and web are supported. iOS and additional sign-in providers are not
currently planned.
