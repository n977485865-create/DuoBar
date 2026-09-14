#!/bin/zsh
set -euo pipefail
DUOBAR_APP="${1:?Usage: verify-app.sh /path/to/DuoBar.app}"
# A distributable app contains only its native application files. Reject stale build files,
# embedded tools and symlinks, including when packaging with --skip-build.
DUOBAR_ACTUAL=$(cd "$DUOBAR_APP" && /usr/bin/find . -mindepth 1 ! -type d | LC_ALL=C /usr/bin/sort)
DUOBAR_EXPECTED='./Contents/Info.plist
./Contents/MacOS/DuoBar
./Contents/PkgInfo
./Contents/Resources/AppIcon.icns
./Contents/Resources/Metadata.appintents/extract.actionsdata
./Contents/Resources/Metadata.appintents/version.json
./Contents/_CodeSignature/CodeResources'
if [[ "$DUOBAR_ACTUAL" != "$DUOBAR_EXPECTED" ]]; then
    print -u2 'Unexpected application contents; rebuild before packaging.'
    print -u2 -- "$DUOBAR_ACTUAL"
    exit 1
fi
if [[ -n "$(/usr/bin/find "$DUOBAR_APP" -type l -print)" ]]; then
    print -u2 'Application must not contain symlinks.'
    exit 1
fi
/usr/bin/plutil -lint "$DUOBAR_APP/Contents/Info.plist"
DUOBAR_ARCHS=$(xcrun lipo -archs "$DUOBAR_APP/Contents/MacOS/DuoBar")
if [[ " $DUOBAR_ARCHS " != *" arm64 "* || " $DUOBAR_ARCHS " != *" x86_64 "* ]]; then
    print -u2 "Missing required application architecture: $DUOBAR_ARCHS"
    exit 1
fi
/usr/bin/codesign --verify --deep --strict "$DUOBAR_APP"
# Missing metadata recreates the user-visible bug: DuoBar never appears in
# System Settings, even though the Swift code compiled successfully.
if ! /usr/bin/grep -q 'DuoBarFocusFilter' "$DUOBAR_APP/Contents/Resources/Metadata.appintents/extract.actionsdata"; then
    print -u2 'Missing native DuoBar Focus filter registration.'
    exit 1
fi
DUOBAR_EXTERNAL=$(xcrun otool -L "$DUOBAR_APP/Contents/MacOS/DuoBar" | /usr/bin/awk '/^[[:space:]]/ { if ($1 !~ /^\/System\/Library\// && $1 !~ /^\/usr\/lib\//) print $1 }')
if [[ -n "$DUOBAR_EXTERNAL" ]]; then
    print -u2 'Unexpected non-system runtime dependency:'
    print -u2 -- "$DUOBAR_EXTERNAL"
    exit 1
fi
print 'Verified: native app files, Focus filter metadata, both architectures, valid signature, system libraries only.'
