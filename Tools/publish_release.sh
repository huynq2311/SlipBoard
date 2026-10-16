#!/usr/bin/env bash
#
# Publish what ./build_release.sh left in Release/ as the latest GitHub release,
# then start the Homebrew tap's bump workflow so the cask follows at once
# instead of at the tap's next 6-hourly run.
#
#   Tools/publish_release.sh <notes.md>
#
# Uses your gh login. Run it from the clean, pushed commit the release was built from.

set -euo pipefail
cd "$(dirname "$0")/.."

REPO="huynq2311/SlipBoard"
TAP_REPO="huynq2311/homebrew-tap"
OUT_DIR="Release"
APP_NAME="SlipBoard"

NOTES="${1:-}"
[ -n "$NOTES" ] && [ -f "$NOTES" ] || { echo "Usage: $0 <notes.md>" >&2; exit 2; }

for f in "$APP_NAME.app" "$APP_NAME.dmg" "$APP_NAME.dmg.sha256" appcast.xml; do
  [ -e "$OUT_DIR/$f" ] || { echo "Missing $OUT_DIR/$f; run ./build_release.sh with SIGN_IDENTITY first." >&2; exit 1; }
done

PLIST="$OUT_DIR/$APP_NAME.app/Contents/Info.plist"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$PLIST")"
BUILD="$(plutil -extract CFBundleVersion raw "$PLIST")"
TAG="v$VERSION-$BUILD"

( cd "$OUT_DIR" && shasum -a 256 -c "$APP_NAME.dmg.sha256" )
APPCAST="$(cat "$OUT_DIR/appcast.xml")"
if ! grep -q "<sparkle:version>$BUILD</sparkle:version>" <<<"$APPCAST" \
  || ! grep -q "/releases/download/$TAG/$APP_NAME.dmg" <<<"$APPCAST"; then
  echo "$OUT_DIR/appcast.xml is not for $TAG." >&2
  exit 1
fi

# The tag points at HEAD, so HEAD must be what was built and must be on GitHub.
if [ -n "$(git status --porcelain)" ]; then
  echo "The working tree has changes; publish from the commit the release was built from." >&2
  exit 1
fi
COMMIT="$(git rev-parse HEAD)"
git fetch --quiet origin
if [ -z "$(git branch -r --contains "$COMMIT")" ]; then
  echo "$COMMIT is not pushed to origin." >&2
  exit 1
fi

gh release create "$TAG" --repo "$REPO" --target "$COMMIT" \
  --title "$APP_NAME v$VERSION (Build $BUILD)" --notes-file "$NOTES" --latest \
  "$OUT_DIR/$APP_NAME.dmg" "$OUT_DIR/$APP_NAME.dmg.sha256" "$OUT_DIR/appcast.xml"

# The release is out either way; if this fails, the tap catches up on its schedule.
if ! gh workflow run bump-slipboard.yml --repo "$TAP_REPO"; then
  echo "Could not start the Homebrew tap's bump workflow; it runs every 6 hours anyway." >&2
fi
