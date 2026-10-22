#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="NotchEye"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
BUILD_DIR="$SCRIPT_DIR/.build"

echo "🔨 Building $APP_NAME (Ultra-low footprint native Cocoa/AppKit)..."
echo ""

mkdir -p "$BUILD_DIR"

# Compile with Apple Clang (arm64, -O3, zero dependencies)
echo "  Compiling native Objective-C sources..."
clang -O3 -fobjc-arc \
  -arch arm64 \
  -framework Cocoa \
  -framework CoreMediaIO \
  -framework AVFoundation \
  -framework UserNotifications \
  -framework QuartzCore \
  -I"$SCRIPT_DIR/src" \
  "$SCRIPT_DIR/src/CameraMonitor.m" \
  "$SCRIPT_DIR/src/NotchIslandView.m" \
  "$SCRIPT_DIR/src/NotchOverlayWindow.m" \
  "$SCRIPT_DIR/src/AppDelegate.m" \
  "$SCRIPT_DIR/src/main.m" \
  -o "$BUILD_DIR/$APP_NAME"

echo "  ✅ Compiled successfully"

# Create .app bundle
echo "  Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Sign with ad-hoc signature for local use
echo "  Signing..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || echo "  ⚠️  Codesign skipped (non-critical for local use)"

BINARY_SIZE=$(ls -lh "$APP_BUNDLE/Contents/MacOS/$APP_NAME" | awk '{print $5}')
BUNDLE_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)

echo ""
echo "✅ Built $APP_NAME.app"
echo "   Binary size: $BINARY_SIZE"
echo "   Bundle size: $BUNDLE_SIZE"
echo "   Location: $APP_BUNDLE"
echo ""
echo "🚀 To run:"
echo "   open \"$APP_BUNDLE\""
echo ""
echo "📦 To install:"
echo "   cp -r \"$APP_BUNDLE\" /Applications/"
