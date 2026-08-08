#!/usr/bin/env bash
# Build the web release and publish it to GitHub Pages.
#
# The built app lives on an orphan `gh-pages` branch so the source history stays
# clean and Pages has nothing to build for itself.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="https://github.com/MFisenko/overseer.git"
BASE="/overseer/"

echo "→ tests"
flutter test

echo "→ build"
flutter build web --release --base-href "$BASE"

echo "→ stage"
STAGE="$(mktemp -d)"
cp -R build/web/* "$STAGE/"
# Pages runs Jekyll by default, which drops files and directories beginning with
# an underscore — including some Flutter assets.
touch "$STAGE/.nojekyll"
# Pages has no SPA rewrite rule; serving index.html as the 404 achieves one.
cp "$STAGE/index.html" "$STAGE/404.html"

echo "→ publish"
cd "$STAGE"
git init -q
git checkout -q -b gh-pages
git add -A
git commit -q -m "Deploy $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git remote add origin "$REPO"
git push -f -q origin gh-pages

rm -rf "$STAGE"
echo "✓ https://mfisenko.github.io/overseer/"
