#!/bin/zsh
set -euo pipefail
DUOBAR_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
DUOBAR_BUILD="$DUOBAR_ROOT/build"
mkdir -p "$DUOBAR_BUILD"
DUOBAR_STAGE=$(mktemp -d "$DUOBAR_BUILD/app-stage.XXXXXX")
trap 'rm -rf "$DUOBAR_STAGE"' EXIT
DUOBAR_APP="$DUOBAR_STAGE/DuoBar.app"
# Xcode generates the App Intents metadata that makes DuoBar appear among
# macOS Focus filters. A swiftc-only app can compile but cannot be configured.
if ! xcrun --find appintentsmetadataprocessor >/dev/null 2>&1; then
    print -u2 'Full Xcode is required to build the Focus filter. Command Line Tools alone are insufficient.'
    exit 1
fi
xcodebuild -quiet -project "$DUOBAR_ROOT/DuoBar.xcodeproj" -target DuoBar \
    -configuration Release -sdk macosx \
    CONFIGURATION_BUILD_DIR="$DUOBAR_STAGE" \
    OBJROOT="$DUOBAR_BUILD/xcode-intermediates" \
    SYMROOT="$DUOBAR_BUILD/xcode-products" CODE_SIGNING_ALLOWED=NO
/usr/bin/plutil -lint "$DUOBAR_APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$DUOBAR_APP"
"$DUOBAR_ROOT/scripts/verify-app.sh" "$DUOBAR_APP"
# Replace only the generated app, after the fresh bundle has passed validation.
rm -rf "$DUOBAR_BUILD/DuoBar.app"
mv "$DUOBAR_APP" "$DUOBAR_BUILD/DuoBar.app"
printf 'Built: %s\n' "$DUOBAR_BUILD/DuoBar.app"
