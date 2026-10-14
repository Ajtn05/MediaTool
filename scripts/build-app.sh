#!/bin/bash
# Build a local macOS app bundle. Extra arguments are forwarded to swift build.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MediaTool"
BUNDLE_ID="com.local.mediatool"
APP_VERSION="1.0.0"
APP_DIR="${PROJECT_ROOT}/dist/${APP_NAME}.app"

cd "$PROJECT_ROOT"

for tool in swift magick codesign; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required tool not found: $tool" >&2
    echo "Install Apple's Command Line Tools and ImageMagick; see README.md." >&2
    exit 1
  fi
done

echo "Building release executable…"
swift build --configuration release "$@"
BIN_PATH="$(swift build --configuration release --show-bin-path "$@")/${APP_NAME}"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "Build did not produce an executable at $BIN_PATH" >&2
  exit 1
fi

# Assemble in a temporary directory so a failed build leaves the last app intact.
SCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mediatool-build.XXXXXX")"
trap 'rm -rf "$SCRATCH_DIR"' EXIT
CONTENTS="${SCRATCH_DIR}/${APP_NAME}.app/Contents"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"
cp "$BIN_PATH" "${CONTENTS}/MacOS/${APP_NAME}"

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key><string>${APP_VERSION}</string>
    <key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.video</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
</dict>
</plist>
PLIST

echo "Generating app icon…"
ICONSET="${SCRATCH_DIR}/AppIcon.iconset"
MASTER="${SCRATCH_DIR}/app-icon.png"
mkdir -p "$ICONSET"

# Render the white vector artwork over a dark gradient once, then downscale it.
# Drawing the gradient here also works with ImageMagick's built-in SVG renderer.
magick -size 1024x1024 gradient:'#2C2C36-#08080A' \
  \( -background none "${PROJECT_ROOT}/assets/icon.svg" -resize 1024x1024 \) \
  -composite "$MASTER"

for size in 16 32 128 256 512; do
  magick "$MASTER" -resize "${size}x${size}" -depth 8 \
    "${ICONSET}/icon_${size}x${size}.png"
  magick "$MASTER" -resize "$((size * 2))x$((size * 2))" -depth 8 \
    "${ICONSET}/icon_${size}x${size}@2x.png"
done

ICON_OUTPUT="${CONTENTS}/Resources/AppIcon.icns"
if ! iconutil -c icns "$ICONSET" -o "$ICON_OUTPUT"; then
  echo "iconutil could not pack the iconset; using the PNG-backed ICNS helper."
  python3 "${PROJECT_ROOT}/scripts/make_icns.py" "$ICONSET" "$ICON_OUTPUT"
fi

# Ad-hoc signing is for local use. Distribution requires separate signing and notarization.
codesign --force --sign - "${SCRATCH_DIR}/${APP_NAME}.app"

mkdir -p "${PROJECT_ROOT}/dist"
rm -rf "$APP_DIR"
mv "${SCRATCH_DIR}/${APP_NAME}.app" "$APP_DIR"
echo "Built ${APP_DIR}"
echo "Run it with: open dist/${APP_NAME}.app"
