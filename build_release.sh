#!/usr/bin/env bash
#
# Build SlipBoard in Release configuration and package it as a DMG.
#
#   ./build_release.sh              ad-hoc signed build (runs on any Mac, never expires)
#   ./build_release.sh --team       team-signed build (Apple Development + provisioning profile)
#   ./build_release.sh --no-sign    unsigned build (what CI builds)
#
# Output: Release/SlipBoard.app, Release/SlipBoard.dmg, Release/SlipBoard.dmg.sha256
#
# Optional settings, read from a .env file next to this script (see .env.example):
#   DEVELOPMENT_TEAM   Apple team ID used for signing. Defaults to the project's team.
#   NOTARY_PROFILE     notarytool keychain profile. When set, and the app is signed
#                      with a Developer ID certificate, the DMG is notarized and stapled.

set -euo pipefail
cd "$(dirname "$0")"

PROJECT="SlipBoard.xcodeproj"
SCHEME="SlipBoard"
APP_NAME="SlipBoard"
BUILD_DIR="build"
OUT_DIR="Release"

# adhoc: signed with "-", no provisioning profile and no entitlements. macOS kills
# an ad-hoc app that claims keychain-access-groups, so App Lock falls back to the
# login keychain. team: needs a valid profile; a free team's profile lasts 7 days.
SIGN_MODE=adhoc
for arg in "$@"; do
  case "$arg" in
    --team) SIGN_MODE=team ;;
    --no-sign) SIGN_MODE=none ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

say() { printf '\n==> %s\n' "$*"; }

VERSION="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^ *MARKETING_VERSION/ {print $2; exit}')"
BUILD_DATE="$(date +%Y%m%d)"

say "Building $APP_NAME $VERSION (build $BUILD_DATE)"
rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$OUT_DIR"

XCODEBUILD_ARGS=(-project "$PROJECT" -scheme "$SCHEME" -configuration Release -derivedDataPath "$BUILD_DIR")
case "$SIGN_MODE" in
  team)
    XCODEBUILD_ARGS+=(-allowProvisioningUpdates)
    if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
      XCODEBUILD_ARGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
    fi
    ;;
  adhoc)
    # CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO keeps get-task-allow (debugger attach) out.
    XCODEBUILD_ARGS+=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
      PROVISIONING_PROFILE_SPECIFIER= CODE_SIGN_ENTITLEMENTS= CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
    ;;
  none)
    XCODEBUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO)
    ;;
esac
xcodebuild "${XCODEBUILD_ARGS[@]}" build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
[ -d "$APP_PATH" ] || { echo "Build did not produce $APP_PATH" >&2; exit 1; }
cp -R "$APP_PATH" "$OUT_DIR/"

if [ "$SIGN_MODE" != none ]; then
  say "Verifying signature"
  codesign --verify --deep --strict "$OUT_DIR/$APP_NAME.app"
  codesign -dv "$OUT_DIR/$APP_NAME.app" 2>&1 | grep -E 'Signature=|Authority=|TeamIdentifier=' || true
fi
if [ "$SIGN_MODE" = adhoc ] && codesign -d --entitlements - "$OUT_DIR/$APP_NAME.app" 2>/dev/null | grep -q keychain-access-groups; then
  echo "Ad-hoc build carries keychain-access-groups; macOS would kill it at launch." >&2
  exit 1
fi

say "Creating DMG"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$OUT_DIR/$APP_NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$OUT_DIR/$APP_NAME.dmg" >/dev/null

if [ -n "${NOTARY_PROFILE:-}" ]; then
  if codesign -dvv "$OUT_DIR/$APP_NAME.app" 2>&1 | grep -q 'Authority=Developer ID Application'; then
    say "Notarizing (profile: $NOTARY_PROFILE)"
    xcrun notarytool submit "$OUT_DIR/$APP_NAME.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$OUT_DIR/$APP_NAME.dmg"
  else
    echo "NOTARY_PROFILE is set but the app is not signed with a Developer ID certificate; skipping notarization." >&2
  fi
fi

( cd "$OUT_DIR" && shasum -a 256 "$APP_NAME.dmg" > "$APP_NAME.dmg.sha256" )

say "Done"
echo "  App:      $OUT_DIR/$APP_NAME.app"
echo "  DMG:      $OUT_DIR/$APP_NAME.dmg ($(du -h "$OUT_DIR/$APP_NAME.dmg" | cut -f1))"
echo "  SHA-256:  $(cut -d' ' -f1 "$OUT_DIR/$APP_NAME.dmg.sha256")"
echo "  Tag:      v$VERSION-$BUILD_DATE"
echo "  Title:    $APP_NAME v$VERSION (Build $BUILD_DATE)"
