#!/bin/bash
# Build a universal macOS app and a compressed drag-to-Applications disk image.
# Extra arguments are forwarded to swift build. Set APP_VERSION to override the version.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MediaTool"
APP_DIR="${PROJECT_ROOT}/dist/${APP_NAME}.app"

for tool in hdiutil ditto lipo shasum; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required tool not found: $tool" >&2
    exit 1
  fi
done

"${PROJECT_ROOT}/scripts/build-app.sh" --arch arm64 --arch x86_64 "$@"
for arch in arm64 x86_64; do
  lipo "${APP_DIR}/Contents/MacOS/${APP_NAME}" -verify_arch "$arch"
done
codesign --verify --deep --strict "$APP_DIR"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_DIR}/Contents/Info.plist")"
DMG_NAME="${APP_NAME}-${APP_VERSION}-universal.dmg"
DMG_PATH="${PROJECT_ROOT}/dist/${DMG_NAME}"

SCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mediatool-dmg.XXXXXX")"
trap 'rm -rf "$SCRATCH_DIR"' EXIT
STAGING_DIR="${SCRATCH_DIR}/staging"
mkdir -p "$STAGING_DIR"
ditto "$APP_DIR" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

cat > "${STAGING_DIR}/Read Me.txt" <<'README'
MediaTool

Installation
1. Drag MediaTool.app to the Applications folder.
2. Eject this disk image and open MediaTool from Applications.

Requires macOS 13 Ventura or later. Supports Apple silicon and Intel Macs.
MediaTool uses tools installed on your Mac; they are not bundled with the app.
Install FFmpeg and ImageMagick with Homebrew:
  brew install ffmpeg imagemagick
For image-to-PDF output, also install Ghostscript:
  brew install ghostscript

This build is ad-hoc signed and has not been notarized by Apple. If macOS blocks
the app on first launch, review Apple's instructions for opening an app you trust:
  https://support.apple.com/en-us/102445

Source, releases, and usage:
  https://github.com/Ajtn05/MediaTool
README

echo "Creating ${DMG_NAME}…"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" \
  -fs HFS+ -format UDZO "${SCRATCH_DIR}/${DMG_NAME}"
hdiutil verify "${SCRATCH_DIR}/${DMG_NAME}"

# Only replace the previous image after creation and verification succeed.
mv -f "${SCRATCH_DIR}/${DMG_NAME}" "$DMG_PATH"
cd "${PROJECT_ROOT}/dist"
shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256"
echo "Built ${DMG_PATH}"
echo "Checksum: ${DMG_PATH}.sha256"
