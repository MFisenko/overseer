#!/usr/bin/env bash
# Dev server for the browser preview. Runs from the repo root regardless of
# where it was invoked, so the harness's launch.json can stay path-agnostic.
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_ARGS=()
if [[ -f .env ]]; then
  ENV_ARGS+=(--dart-define-from-file=.env)
fi

exec flutter run -d web-server \
  --web-port "${PORT:-5599}" \
  --web-hostname 127.0.0.1 \
  "${ENV_ARGS[@]}"
