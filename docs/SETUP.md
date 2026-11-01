# Development and deployment

[Back to Cue](../README.md) · [Quick start](../README.md#quick-start)

Use Flutter 3.47.9 (the CI version), Node 22+, and Android SDK tools for phone
builds. App and Worker commands run in separate terminals.

## Local Worker

```sh
cd worker
npm ci
npx wrangler d1 migrations apply cue-sync --local
npx wrangler dev
```

The Worker listens on port 8787. Optional local keys belong in gitignored
`worker/.dev.vars`; use `.dev.vars.example` as the template.
Never put credentials in the app or tracked files.

## App

```sh
cd app
flutter pub get
flutter run -d chrome --web-port 7357
```

Debug web builds use `http://127.0.0.1:8787`; Android emulator debug builds use
`http://10.0.2.2:8787`. Release builds default to the hosted Cue Worker.
Override it with `--dart-define=CUE_API=https://<your-worker>.workers.dev`.

```sh
flutter build apk --release
```

Output: `app/build/app/outputs/flutter-apk/app-release.apk`.
Copy it to your phone, open it and allow installation from the sending app.
Signing uses gitignored `app/android/key.properties`; missing credentials cause
the documented debug-key fallback, not a store-ready release.

## Deploy your own Worker

The bounded architecture targets Cloudflare's free plan. Quotas and provider
policies can change; handle unavailable/quota errors rather than assuming
guaranteed capacity. Configure your own KV/D1 IDs and `ALLOWED_ORIGINS` in
`worker/wrangler.toml`.

```sh
cd worker
npx wrangler d1 migrations apply cue-sync --remote
npx wrangler deploy --keep-vars
```

This deploys the Worker, not the Flutter website. It preserves existing dashboard
variables, but review config before deploying. Diagnostics needs migration
`0002_diagnostics.sql` and the matching Worker.

Build web assets from `app/`, using a POSIX shell:

```sh
tool/build_web.sh https://<your-worker>.workers.dev
```

The script builds `app/build/web` and fills the API origin into its CSP.
Publish that folder using your static host, with SPA fallback and the supplied
headers. Running `wrangler deploy` with the API's config does **not** publish
the Flutter web folder.

## Optional provider keys

Set production secrets from `worker/` using `npx wrangler secret put NAME`.
Do not expose keys in public issues, URLs, logs or app bundles.

| Name | Enables | Get it at |
|---|---|---|
| `MAL_CLIENT_ID` (var) + `MAL_CLIENT_SECRET` | MyAnimeList sign-in and username import | myanimelist.net/apiconfig |
| `GROQ_API_KEY` | Smarter mood text | console.groq.com |
| `GEMINI_API_KEY` | Smarter mood fallback | aistudio.google.com |
| `TMDB_API_KEY` | Optional richer drama, series and movie metadata | themoviedb.org |

Provider free tiers are subject to their own quotas and changes.
For MyAnimeList, register both `https://<your-site>/auth.html` and
`cue://oauth/mal` as redirect URLs.

## Sync and diagnostics

Sync needs no Cue account. On one device, Turn on sync creates a code; Join it
on another. If the cloud copy was cleared, Sync now on a device with the saved
code recreates it from that device's local library. Joining before recreation
reports that no copy exists.

Enable Share technical diagnostics in Settings > Privacy to collect **new**
technical requests. Export/recovery codes are private and separate from sync.
See [diagnostics operations](../worker/DIAGNOSTICS.md) and
[privacy details](PRIVACY.md).
