#!/usr/bin/env bash
# Builds the web app and fills the Worker origin into the CSP.
# Usage: tool/build_web.sh <worker-origin>   e.g. http://127.0.0.1:8787
set -euo pipefail
origin="${1:?worker origin required, e.g. https://cue-worker.example.workers.dev}"
case "$origin" in
  http://127.0.0.1:*|http://localhost:*|https://*) ;;
  *) echo "origin must be https (or localhost for dev)" >&2; exit 1 ;;
esac
cd "$(dirname "$0")/.."
flutter build web --release --no-web-resources-cdn --dart-define=CUE_API="$origin"
for f in build/web/index.html build/web/_headers; do
  sed -i "s#CUE_API_ORIGIN#${origin}#g" "$f"
done
grep -q CUE_API_ORIGIN build/web/index.html build/web/_headers && { echo "placeholder left" >&2; exit 1; } || true
echo "Built build/web for $origin"
