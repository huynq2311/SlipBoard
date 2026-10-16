#!/usr/bin/env bash
#
# Build SlipBoard in Release configuration and package it as a DMG.
#
#   ./build_release.sh              signed with SIGN_IDENTITY if set (releases), else ad-hoc;
#                                   runs on any Mac, never expires
#   ./build_release.sh --team       team-signed build (Apple Development + provisioning profile)
#   ./build_release.sh --no-sign    unsigned build (what CI builds)
#
# Output: Release/SlipBoard.app, Release/SlipBoard.dmg, Release/SlipBoard.dmg.sha256,
#         and Release/appcast.xml for signed releases
#
# Optional settings, read from a .env file next to this script (see .env.example):
#   DEVELOPMENT_TEAM   Apple team ID used for signing. Defaults to the project's team.
#   SIGN_IDENTITY      Self-signed code signing certificate for the default build.
#                      The same certificate keeps the Accessibility permission
#                      across updates; without it each build is ad-hoc signed.
#   NOTARY_PROFILE     notarytool keychain profile. When set, and the app is signed
#                      with a Developer ID certificate, the DMG is notarized and stapled.

set -euo pipefail
cd "$(dirname "$0")"

PROJECT="SlipBoard.xcodeproj"
SCHEME="SlipBoard"
APP_NAME="SlipBoard"
BUILD_DIR="build"
OUT_DIR="Release"

# adhoc: signed with "-", no provisioning profile. macOS kills an ad-hoc app that
# claims keychain-access-groups, so App Lock keeps its key in a 0600 file instead.
# Its only entitlement turns off library validation: without a Team ID, macOS
# refuses to load Sparkle.framework into the app even when both share a certificate.
# The app makes up for it: Sparkle lives inside PlugIns/SlipBoardUpdater.bundle, which
# the app loads only after checking that the plug-in and the framework carry its own
# certificate (SlipBoard/Core/Updates/UpdaterSignatureCheck.swift).
# team: needs a valid profile; a free team's profile lasts 7 days.
SIGN_MODE=adhoc
for arg in "$@"; do
  case "$arg" in
    --team) SIGN_MODE=team ;;
    --no-sign) SIGN_MODE=none ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# CDHash of every architecture slice of each signed bundle's executable, one per line.
library_cdhashes() {
  local bundle executable arch cdhash
  for bundle in "$@"; do
    executable="$(codesign -dv "$bundle" 2>&1 | awk -F= '/^Executable=/{print $2}')"
    for arch in $(lipo -archs "$executable"); do
      cdhash="$(codesign -dvvv --arch "$arch" "$bundle" 2>&1 | awk -F= '/^CDHash=/{print $2}')"
      [ -n "$cdhash" ] || { echo "No CDHash for the $arch slice of $bundle." >&2; return 1; }
      echo "$cdhash"
    done
  done
}

VERSION="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^ *MARKETING_VERSION/ {print $2; exit}')"
# Override for a second release on the same day, e.g. BUILD_DATE=20261016.2.
BUILD_DATE="${BUILD_DATE:-$(date +%Y%m%d)}"

say "Building $APP_NAME $VERSION (build $BUILD_DATE)"
rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$OUT_DIR"

# CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO keeps get-task-allow (debugger attach) out of
# every signed build; Apple Development signing adds it otherwise.
XCODEBUILD_ARGS=(-project "$PROJECT" -scheme "$SCHEME" -configuration Release -derivedDataPath "$BUILD_DIR")
case "$SIGN_MODE" in
  team)
    XCODEBUILD_ARGS+=(-allowProvisioningUpdates CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
    if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
      XCODEBUILD_ARGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
    fi
    ;;
  adhoc)
    XCODEBUILD_ARGS+=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
      PROVISIONING_PROFILE_SPECIFIER= CODE_SIGN_ENTITLEMENTS=SlipBoard-NoTeam.entitlements \
      CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
    ;;
  none)
    XCODEBUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO)
    ;;
esac
# The build number shown in Settings → About matches the release tag's date.
xcodebuild "${XCODEBUILD_ARGS[@]}" CURRENT_PROJECT_VERSION="$BUILD_DATE" build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
[ -d "$APP_PATH" ] || { echo "Build did not produce $APP_PATH" >&2; exit 1; }
cp -R "$APP_PATH" "$OUT_DIR/"

if [ "$SIGN_MODE" = adhoc ] && [ -n "${SIGN_IDENTITY:-}" ]; then
  say "Signing with $SIGN_IDENTITY"
  sign() { codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$@"; }
  # Inside out, as Sparkle's docs list it, then the plug-in that holds Sparkle.
  # The app loads them only if they carry this same certificate.
  PLUGIN="$OUT_DIR/$APP_NAME.app/Contents/PlugIns/SlipBoardUpdater.bundle"
  SPARKLE="$PLUGIN/Contents/Frameworks/Sparkle.framework"
  sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
  sign --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
  sign "$SPARKLE/Versions/B/Autoupdate"
  sign "$SPARKLE/Versions/B/Updater.app"
  sign "$SPARKLE"
  sign "$PLUGIN"
  # With library validation off, dyld would load any validly signed code once the
  # app's check has passed, so a file swapped between the check and Bundle.load()
  # could still run. This constraint lets the app load only these exact builds of
  # the plug-in and Sparkle; OS libraries are exempt. Team builds keep library
  # validation, which already limits loads to their own team, and get none.
  LIBRARY_CONSTRAINT="$(mktemp -d)/library-constraint.plist"
  plutil -create xml1 "$LIBRARY_CONSTRAINT"
  plutil -insert cdhash -dictionary "$LIBRARY_CONSTRAINT"
  plutil -insert 'cdhash.$in' -array "$LIBRARY_CONSTRAINT"
  library_cdhashes "$PLUGIN" "$SPARKLE" | while read -r cdhash; do
    plutil -insert 'cdhash.$in' -data "$(xxd -r -p <<<"$cdhash" | base64)" -append "$LIBRARY_CONSTRAINT"
  done
  sign --entitlements SlipBoard-NoTeam.entitlements --library-constraint "$LIBRARY_CONSTRAINT" \
    "$OUT_DIR/$APP_NAME.app"
fi

# Sparkle must reach the app only through the plug-in, after its signature check.
LINKED="$(otool -L "$OUT_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME")"
if grep -q Sparkle <<<"$LINKED"; then
  echo "The app executable links Sparkle; only SlipBoardUpdater.bundle may." >&2
  exit 1
fi

if [ "$SIGN_MODE" != none ]; then
  say "Verifying signature"
  codesign --verify --deep --strict "$OUT_DIR/$APP_NAME.app"
  # The app loads the updater only if it matches the app's own certificate
  # (UpdaterSignatureCheck); check the same here so a release never ships with
  # updates silently off. Ad-hoc builds have no certificate and no updates.
  CERT_DIR="$(mktemp -d)"
  codesign -d --extract-certificates="$CERT_DIR/cert" "$OUT_DIR/$APP_NAME.app" 2>/dev/null || true
  if [ -f "$CERT_DIR/cert0" ]; then
    LEAF="$(shasum -a 1 "$CERT_DIR/cert0" | cut -d' ' -f1)"
    PLUGIN="$OUT_DIR/$APP_NAME.app/Contents/PlugIns/SlipBoardUpdater.bundle"
    codesign --verify --deep --strict \
      -R="identifier \"org.sparkle-project.Sparkle\" and certificate leaf = H\"$LEAF\"" \
      "$PLUGIN/Contents/Frameworks/Sparkle.framework"
    codesign --verify --deep --strict \
      -R="identifier \"huynq.SlipBoard.Updater\" and certificate leaf = H\"$LEAF\"" "$PLUGIN"
  fi
  rm -rf "$CERT_DIR"
  if [ -n "${LIBRARY_CONSTRAINT:-}" ]; then
    # Every slice must carry the constraint, and it must list the plug-in and
    # Sparkle as they are now: a stale CDHash would keep updates from loading.
    for arch in $(lipo -archs "$OUT_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"); do
      SIGNATURE="$(codesign -dvvv --arch "$arch" "$OUT_DIR/$APP_NAME.app" 2>&1)"
      grep -q 'Has Library Load Constraints' <<<"$SIGNATURE" \
        || { echo "The $arch slice of the app has no library load constraint." >&2; exit 1; }
    done
    LISTED="$(count="$(plutil -extract 'cdhash.$in' raw -o - "$LIBRARY_CONSTRAINT")"
      for ((i = 0; i < count; i++)); do
        plutil -extract "cdhash.\$in.$i" raw -o - "$LIBRARY_CONSTRAINT" | base64 -d | xxd -p
      done)"
    CURRENT="$(library_cdhashes "$PLUGIN" "$PLUGIN/Contents/Frameworks/Sparkle.framework")"
    if [ "$LISTED" != "$CURRENT" ]; then
      echo "The library constraint does not list the plug-in and Sparkle as signed." >&2
      exit 1
    fi
    rm -rf "$(dirname "$LIBRARY_CONSTRAINT")"
  fi
  codesign -dv "$OUT_DIR/$APP_NAME.app" 2>&1 | grep -E 'Signature=|Authority=|TeamIdentifier=' || true
  # get-task-allow lets any local process attach to the app and read decrypted history.
  ENTITLEMENTS="$(codesign -d --entitlements - "$OUT_DIR/$APP_NAME.app" 2>/dev/null || true)"
  if grep -q get-task-allow <<<"$ENTITLEMENTS"; then
    echo "Release build carries com.apple.security.get-task-allow; refusing to package it." >&2
    exit 1
  fi
fi
if [ "$SIGN_MODE" = adhoc ] && codesign -d --entitlements - "$OUT_DIR/$APP_NAME.app" 2>/dev/null | grep -q keychain-access-groups; then
  echo "Build without a profile carries keychain-access-groups; macOS would kill it at launch." >&2
  exit 1
fi

say "Creating DMG"
# Finder lays out the window of a mounted volume by name, so another volume
# with the same name would get the layout instead.
if [ -e "/Volumes/$APP_NAME" ]; then
  echo "Eject /Volumes/$APP_NAME first." >&2
  exit 1
fi
WORK="$(mktemp -d)"
MOUNT_DIR=""
cleanup() {
  if [ -n "$MOUNT_DIR" ]; then hdiutil detach "$MOUNT_DIR" -quiet || true; fi
  rm -rf "$WORK"
}
trap cleanup EXIT
STAGE="$WORK/stage"
mkdir -p "$STAGE/.background"
cp -R "$OUT_DIR/$APP_NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
# One TIFF holding the 1x and 2x images, so the window is sharp on Retina.
tiffutil -cathidpicheck Tools/dmg/background.png Tools/dmg/background@2x.png \
  -out "$STAGE/.background/background.tiff" >/dev/null

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg" >/dev/null
MOUNT_DIR="$(hdiutil attach "$WORK/rw.dmg" -readwrite -noverify -noautoopen | awk -F'\t' '/\/Volumes\// {print $NF}')"
# Without this, a failed attach would leave the paths below pointing at /.
[ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ] || { echo "Could not mount the writable DMG." >&2; exit 1; }

# Window size and icon positions match Tools/dmg/make-background.swift.
# Finder needs Automation permission for the app running this script.
if osascript - "$APP_NAME" <<'APPLESCRIPT'
on run argv
  set volumeName to item 1 of argv
  tell application "Finder"
    tell disk volumeName
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {200, 120, 860, 520}
      set viewOptions to icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 128
      set text size of viewOptions to 13
      set background picture of viewOptions to file ".background:background.tiff"
      set position of item (volumeName & ".app") of container window to {170, 190}
      set position of item "Applications" of container window to {490, 190}
      update without registering applications
      close
    end tell
  end tell
end run
APPLESCRIPT
then
  # Finder writes .DS_Store asynchronously after the window closes.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -f "$MOUNT_DIR/.DS_Store" ] && break
    sleep 1
  done
  [ -f "$MOUNT_DIR/.DS_Store" ] || echo "Finder did not save the window layout; the DMG opens with default icons." >&2
else
  echo "Could not lay out the DMG window (allow Finder under Privacy & Security → Automation); the DMG opens with default icons." >&2
fi

rm -rf "$MOUNT_DIR/.fseventsd"
hdiutil detach "$MOUNT_DIR" -quiet
MOUNT_DIR=""
hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$OUT_DIR/$APP_NAME.dmg" >/dev/null

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

TAG="v$VERSION-$BUILD_DATE"
if [ "$SIGN_MODE" = adhoc ] && [ -n "${SIGN_IDENTITY:-}" ]; then
  # The app reads releases/latest/download/appcast.xml, so upload this file with the
  # DMG. generate_appcast signs the DMG with the EdDSA key in the login keychain.
  say "Writing appcast"
  mkdir "$WORK/appcast"
  cp "$OUT_DIR/$APP_NAME.dmg" "$WORK/appcast/"
  "$BUILD_DIR/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
    --download-url-prefix "https://github.com/huynq2311/SlipBoard/releases/download/$TAG/" \
    -o "$OUT_DIR/appcast.xml" "$WORK/appcast"
  # Without the private key the appcast is written unsigned, and every client rejects it.
  grep -q 'sparkle:edSignature=' "$OUT_DIR/appcast.xml" \
    || { echo "appcast.xml has no EdDSA signature; is the Sparkle key in the login keychain?" >&2; exit 1; }
fi

say "Done"
echo "  App:      $OUT_DIR/$APP_NAME.app"
echo "  DMG:      $OUT_DIR/$APP_NAME.dmg ($(du -h "$OUT_DIR/$APP_NAME.dmg" | cut -f1))"
echo "  SHA-256:  $(cut -d' ' -f1 "$OUT_DIR/$APP_NAME.dmg.sha256")"
[ -f "$OUT_DIR/appcast.xml" ] && echo "  Appcast:  $OUT_DIR/appcast.xml"
echo "  Tag:      $TAG"
echo "  Title:    $APP_NAME v$VERSION (Build $BUILD_DATE)"
