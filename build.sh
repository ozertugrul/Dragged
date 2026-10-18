#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$DIR/Dragged.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🎯 Building Dragged for macOS Universal (Apple Silicon arm64 + Intel x86_64)..."

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

SWIFT_FILES=("$DIR"/Sources/*.swift)

# 1. Compile Apple Silicon (arm64)
echo "  [1/4] Compiling for Apple Silicon (arm64)..."
swiftc -O \
  -target arm64-apple-macos13.0 \
  -framework AppKit \
  -framework SwiftUI \
  -framework UniformTypeIdentifiers \
  -framework PDFKit \
  -framework UserNotifications \
  "${SWIFT_FILES[@]}" \
  -o "$DIR/Dragged_arm64"

# 2. Compile Intel (x86_64)
echo "  [2/4] Compiling for Intel (x86_64)..."
swiftc -O \
  -target x86_64-apple-macos13.0 \
  -framework AppKit \
  -framework SwiftUI \
  -framework UniformTypeIdentifiers \
  -framework PDFKit \
  -framework UserNotifications \
  "${SWIFT_FILES[@]}" \
  -o "$DIR/Dragged_x86"

# 3. Create Universal Binary with lipo
echo "  [3/4] Creating Universal Fat Binary with lipo..."
lipo -create "$DIR/Dragged_arm64" "$DIR/Dragged_x86" -output "$MACOS_DIR/Dragged"
chmod +x "$MACOS_DIR/Dragged"
rm -f "$DIR/Dragged_arm64" "$DIR/Dragged_x86"

# 4. Copy Resources & Plist
echo "  [4/4] Bundling AppIcon and Info.plist..."
cp "$DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "🔍 Verifying binary architectures:"
lipo -info "$MACOS_DIR/Dragged"

# 5. Packaging Release Artifacts
echo "📦 Packaging Release Artifacts (.zip and .dmg)..."
mkdir -p "$DIR/release"

# ZIP
cd "$DIR"
zip -q -r -y "$DIR/release/Dragged-macOS-Universal.zip" "Dragged.app"

# DMG
rm -f "$DIR/release/Dragged-macOS-Universal.dmg"
hdiutil create -volname "Dragged" \
  -srcfolder "$APP_DIR" \
  -ov -format UDZO \
  "$DIR/release/Dragged-macOS-Universal.dmg" -quiet

echo "✅ SUCCESS: Dragged.app built & packaged!"
echo "   Artifacts available in: $DIR/release/"
ls -lh "$DIR/release/"
